require 'supermarket/import/configuration'

module Supermarket
  module Import
    class Cookbook
      class << self
        extend Configuration

        list_ids_with "SELECT cookbooks.id FROM cookbooks"

        migrate :CookbookRecord => :Cookbook
      end

      def initialize(record)
        @record = record
      end

      def call
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
          created_at: @record.created_at,
          updated_at: @record.updated_at,
          legacy_id: @record.id
        ).tap { |c| c.record_timestamps = false }

        cookbook_versions = @record.cookbook_versions.map do |record|
          ::CookbookVersion.new(
            version: record.version,
            license: record.license,
            tarball_file_name: record.tarball_file_name,
            tarball_content_type: record.tarball_content_type,
            tarball_file_size: record.tarball_file_size,
            tarball_updated_at: record.tarball_updated_at,
            download_count: record.download_count,
            cookbook: cookbook,
            created_at: record.created_at,
            updated_at: record.updated_at,
            legacy_id: record.id
          ).tap { |cv| cv.record_timestamps = false }
        end

        cookbook.cookbook_versions = cookbook_versions
        cookbook.save!
      end
    end
  end
end
