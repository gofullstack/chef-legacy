require 'chef/version_constraint'
require 'net/http'
require 'tempfile'

module Supermarket
  module Import
    class CookbookVersionDependencies
      def self.import(record)
        new(record).call
      end

      def initialize(record)
        @record = record
        @cookbook_record = record.cookbook
        @cookbook = ::Cookbook.with_name(@cookbook_record.name).first!.tap do |c|
          c.record_timestamps = false
        end
        @cookbook_version = @cookbook.cookbook_versions.find_by!(
          version: record.version
        ).tap { |cv| cv.record_timestamps = false }
        @constraint_updates = {
          '>>' => '>',
          '<<' => '<'
        }
      end

      def complete?
        @cookbook_version.dependencies_imported?
      end

      def call(force = false)
        if complete?
          return unless force
        end

        cookbook_upload_parameters do |parameters|
          metadata = parameters.metadata

          @cookbook.update_attribute(:maintainer, metadata.maintainer)

          metadata.dependencies.each do |name, constraint|
            constraints = Array(constraint).map do |original|
              @constraint_updates.reduce(original) do |updated, (old, new)|
                updated.gsub(old, new)
              end
            end

            safe_constraint = Chef::VersionConstraint.new(constraints)

            @cookbook_version.cookbook_dependencies.create!(
              name: name,
              version_constraint: safe_constraint.to_s,
              cookbook: ::Cookbook.with_name(name).first
            )
          end

          @cookbook_version.update_attributes!(
            dependencies_imported: true,
            readme: parameters.readme.contents.to_s,
            readme_extension: parameters.readme.extension.to_s
          )
        end
      end

      def cookbook_upload_parameters
        tarball = Tempfile.new(@cookbook_version.id.to_s, 'tmp').tap do |tb|
          tb.set_encoding 'ASCII-8BIT'
        end

        Net::HTTP.start('s3.amazonaws.com', 80) do |http|
          http.request(Net::HTTP::Get.new(@record.artifact_path)) do |response|
            response.read_body do |chunk|
              tarball.write(chunk)
            end
          end
        end

        tarball.rewind

        options = { cookbook: '{}', tarball: tarball }

        parameters = CookbookUpload::Parameters.new(options)

        if block_given?
          yield parameters
        else
          parameters
        end
      end
    end
  end
end
