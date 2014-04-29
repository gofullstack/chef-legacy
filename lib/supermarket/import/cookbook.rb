module Supermarket
  module Import
    class Cookbook
      def self.import(record)
        new(record).call
      end

      def initialize(record)
        @record = record
      end

      def complete?
        ::Cookbook.with_name(@record.name).count > 0
      end

      def call(force = false)
        if complete?
          return unless force
        end

        category = ::Category.with_name(@record.category.name).first!
        owner = ::Account.
          for('chef_oauth2').
          with_username(@record.maintainer.unique_name).
          first!.
          user

        cookbook = ::Cookbook.new(
          name: @record.name,
          maintainer: 'john@example.com',
          description: @record.description,
          category: category,
          owner: owner,
          source_url: @record.sanitized_external_url.to_s,
          download_count: @record.download_count,
          deprecated: @record.deprecated
        )

        cookbook_versions = @record.cookbook_versions.map do |record|
          ::CookbookVersion.new(
            version: record.version,
            license: record.license,
            tarball_file_name: record.tarball_file_name,
            tarball_content_type: record.tarball_content_type,
            tarball_file_size: record.tarball_file_size,
            tarball_updated_at: record.tarball_updated_at,
            download_count: record.download_count,
            cookbook: cookbook
          )
        end

        cookbook.cookbook_versions = cookbook_versions
        cookbook.save!
      end
    end
  end
end
