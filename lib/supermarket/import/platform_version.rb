require 'supermarket/import/configuration'

module Supermarket
  module Import
    class PlatformVersion
      class << self
        extend Configuration

        list_ids_with %{
          SELECT platform_versions.id
          FROM platform_versions
          INNER JOIN cookbook_versions ON cookbook_versions.id = platform_versions.cookbook_version_id
          INNER JOIN cookbooks ON cookbooks.id = cookbook_versions.cookbook_id
        }

        migrate :PlatformVersionRecord => :CookbookVersionPlatform
      end

      include Enumerable

      def initialize(record)
        @skip = true
        @record = record
        cookbook_name = @record.cookbook_version.cookbook.name
        cookbook_version_id = @record.cookbook_version.id
        @cookbook = ::Cookbook.with_name(cookbook_name).first

        if @cookbook
          @cookbook_version = @cookbook.cookbook_versions.find_by(
            legacy_id: cookbook_version_id
          )

          if @cookbook_version
            @skip = false
          end
        end
      end

      def each
        return if @skip

        identity = {
          name: @record.platform,
          version_constraint: @record.version_constraint
        }

        supported_platform = ::SupportedPlatform.where(identity).first_or_initialize

        @cookbook_version.cookbook_version_platforms.build(
          supported_platform: supported_platform,
          created_at: @record.created_at,
          updated_at: @record.updated_at,
          legacy_id: @record.id
        ).tap do |platform|
          platform.record_timestamps = false

          yield platform
        end
      end
    end
  end
end
