module Supermarket
  module Import
    class PlatformVersion
      def self.import(record)
        new(record).call
      end

      attr_reader :cookbook, :cookbook_version

      def initialize(record)
        @record = record

        if @record.cookbook_version
          cookbook_name = @record.cookbook_version.cookbook.name
          cookbook_version_number = @record.cookbook_version.version
          @cookbook = ::Cookbook.with_name(cookbook_name).first!
          @cookbook_version = cookbook.cookbook_versions.find_by!(
            version: cookbook_version_number
          )
        else
          @skip = true
        end
      end

      def complete?
        @skip || cookbook_version.supported_platforms.where(
          name: @record.platform,
          version_constraint: @record.version_constraint
        ).count > 0
      end

      def call(force = false)
        if complete?
          return unless force
        end

        cookbook_version.supported_platforms.build(
          name: @record.platform,
          version_constraint: @record.version_constraint,
          created_at: @record.created_at,
          updated_at: @record.updated_at
        ).tap do |platform|
          platform.record_timestamps = false
          platform.save!
        end
      end
    end
  end
end
