require 'chef/version_constraint'
require 'net/http'
require 'supermarket/import/configuration'
require 'tempfile'

module Supermarket
  module Import
    class CookbookVersionDependencies
      class << self
        extend Configuration

        list_ids_with %{
          SELECT cookbook_versions.id FROM cookbook_versions
          INNER JOIN cookbooks ON cookbooks.id = cookbook_versions.cookbook_id
        }

        # NOTE: the "migrate" abstraction breaks down a bit here. Our
        # desination isn't CookbookVersion per se, but there is no analogue to
        # CookbookDependency in the existing Community Site. As such, we track
        # import state on CookbookVersion.
        migrate :CookbookVersionRecord => :CookbookVersion

        def imported_legacy_ids
          ::CookbookVersion.where(dependencies_imported: true, legacy_id: ids).pluck(:legacy_id)
        end
      end

      include Enumerable

      class UnableToProcessTarball < RuntimeError
        attr_reader :errors, :cookbook_name, :cookbook_version, :errors

        def initialize(message, cookbook_name, cookbook_version, errors)
          super(message)
          @cookbook_name = cookbook_name
          @cookbook_version = cookbook_version
          @errors = errors
        end
      end

      def initialize(record)
        @skip = true
        @record = record
        @cookbook_record = record.cookbook
        @cookbook = ::Cookbook.with_name(@cookbook_record.name).first

        if @cookbook
          @cookbook.record_timestamps = false
          @cookbook_version = @cookbook.cookbook_versions.find_by(
            version: record.version
          )

          if @cookbook_version
            @skip = false
            @cookbook_version.record_timestamps = false
            @constraint_updates = {
              '>>' => '>',
              '<<' => '<'
            }
          end
        end
      end

      def readonly!
        @readonly = true
      end

      def readonly?
        !!@readonly
      end

      def each
        return if @skip

        if !readonly?
          return if @cookbook_version.dependencies_imported?
        end

        cookbook_upload_parameters do |parameters|
          if parameters.valid?
            metadata = parameters.metadata

            metadata.dependencies.each do |name, constraint|
              constraints = Array(constraint).map do |original|
                @constraint_updates.reduce(original) do |updated, (old, new)|
                  updated.gsub(old, new)
                end
              end

              safe_constraint = Chef::VersionConstraint.new(constraints)

              dependency = @cookbook_version.cookbook_dependencies.build(
                name: name,
                version_constraint: safe_constraint.to_s,
                cookbook: ::Cookbook.with_name(name).first
              )

              dependency.readonly! if readonly?

              yield dependency
            end

            description = [metadata, @cookbook_record].
              map(&:description).
              find { |description| description.to_s.strip.present? }

            @cookbook_version.tap do |version|
              version.assign_attributes(
                dependencies_imported: true,
                description: description,
                readme: parameters.readme.contents.to_s,
                readme_extension: parameters.readme.extension.to_s
              )

              version.readonly! if readonly?

              yield version
            end
          else
            raise UnableToProcessTarball.new(
              'Unable to process cookbook version tarball',
              @cookbook.name,
              @cookbook_version.version,
              parameters.errors
            )
          end
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
