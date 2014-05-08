require 'supermarket/import/configuration'

module Supermarket
  module Import
    class Cookbook
      class << self
        extend Configuration

        list_ids_with "SELECT cookbooks.id FROM cookbooks"

        migrate :CookbookRecord => :Cookbook
      end

      include Enumerable

      def initialize(record)
        @skip = true
        @record = record
        @owner = record.supermarket_owner
        @category = record.supermarket_category

        if @owner && @category
          @skip = false
        end
      end

      def each
        return if @skip

        cookbook_versions = @record.cookbook_versions.
          group_by(&:version).
          map do |_, records|
            # NOTE: as of writing, there are eight cookbooks which have
            # multiple associated CookbookVersion records with the same version
            # number (there is Rails validation against this, but no database
            # constriants). Supermarket's database constraints enforce
            # uniqueness in this regard, so we take the most recently-uploaded
            # version as the version to import
            record = records.max_by(&:created_at)

            ::CookbookVersion.new(
              description: @record.description,
              version: record.version,
              license: record.license,
              tarball_file_name: record.tarball_file_name,
              tarball_content_type: record.tarball_content_type,
              tarball_file_size: record.tarball_file_size,
              tarball_updated_at: record.tarball_updated_at,
              download_count: record.download_count,
              created_at: record.created_at,
              updated_at: record.updated_at,
              legacy_id: record.id
            ).tap do |cookbook_version|
              cookbook_version.record_timestamps = false

              yield cookbook_version
            end
        end

        ::Cookbook.new(
          name: @record.name,
          category: @category,
          owner: @owner,
          source_url: @record.sanitized_external_url.to_s,
          download_count: @record.download_count,
          created_at: @record.created_at,
          updated_at: @record.updated_at,
          legacy_id: @record.id,
          cookbook_versions: cookbook_versions
        ).tap do |cookbook|
          cookbook.record_timestamps = false

          yield cookbook
        end
      end
    end
  end
end
