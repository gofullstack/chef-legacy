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
          INNER JOIN cookbooks ON cookbooks.id = cookbook_versions.id
        }

        migrate :PlatformVersionRecord => :SupportedPlatform
      end

      attr_reader :cookbook, :cookbook_version

      def initialize(record)
        @record = record
        cookbook_name = @record.cookbook_version.cookbook.name
        cookbook_version_number = @record.cookbook_version.version
        @cookbook = ::Cookbook.with_name(cookbook_name).first!
        @cookbook_version = cookbook.cookbook_versions.find_by!(
          version: cookbook_version_number
        )
      end

      def call
        cookbook_version.supported_platforms.build(
          name: @record.platform,
          version_constraint: @record.version_constraint,
          created_at: @record.created_at,
          updated_at: @record.updated_at,
          legacy_id: @record.id
        ).tap do |platform|
          platform.record_timestamps = false
          platform.save!
        end
      end
    end
  end
end
