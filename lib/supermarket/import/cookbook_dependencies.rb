require 'chef/version_constraint'
require 'net/http'
require 'tempfile'

module Supermarket
  module Import
    class CookbookDependencies
      def initialize(cookbook_row, cookbook_version_row)
        @cookbook_row = cookbook_row
        @cookbook_version_row = cookbook_version_row
        @cookbook = Cookbook.with_name(cookbook_row['name']).first!
        @cookbook_version = @cookbook.cookbook_versions.find_by!(version: cookbook_version_row['version'])
        @constraint_updates = {
          '>>' => '>',
          '<<' => '<'
        }
      end

      def necessary?
        !@cookbook_version.dependencies_imported?
      end

      def call
        fetch_metadata do |metadata|
          dependencies = metadata.dependencies

          existing_cookbooks = Cookbook.where(name: dependencies.keys)

          dependencies.each do |name, constraint|
            updated_constraints = Array(constraint).map do |c|
              @constraint_updates.reduce(c) do |updated, (old, new)|
                updated.gsub(old, new)
              end
            end

            safe_constraint = Chef::VersionConstraint.new(updated_constraints)

            @cookbook_version.cookbook_dependencies.create!(
              name: name,
              version_constraint: safe_constraint.to_s,
              cookbook: existing_cookbooks.find { |c| c.name == name }
            )
          end

          @cookbook_version.update_attribute(:dependencies_imported, true)
        end
      end

      def fetch_metadata
        tarball = Tempfile.new(@cookbook_version.id.to_s, 'tmp').tap do |tb|
          tb.set_encoding 'ASCII-8BIT'
        end

        Net::HTTP.start('s3.amazonaws.com', 80) do |http|
          http.request(Net::HTTP::Get.new(artifact_path)) do |response|
            response.read_body do |chunk|
              tarball.write(chunk)
            end
          end
        end

        tarball.rewind

        options = { cookbook: '{}', tarball: tarball }

        parameters = CookbookUpload::Parameters.new(options)

        if block_given?
          yield parameters.metadata
        else
          parameters.metadata
        end
      end

      private

      def artifact_path
        id = @cookbook_version_row['id']
        tarball_file_name = @cookbook_version_row['tarball_file_name']

        unless tarball_file_name.include?('.')
          tarball_file_name << '.'
        end

        "/community-files.opscode.com/cookbook_versions/tarballs/#{id}/original/#{tarball_file_name}"
      end
    end
  end
end
