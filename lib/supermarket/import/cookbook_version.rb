require 'supermarket/import/configuration'

module Supermarket
  module Import
    class CookbookVersion
      class << self
        extend Configuration

        list_ids_with %{
          SELECT cookbook_versions.id FROM cookbook_versions
          INNER JOIN cookbooks ON cookbooks.id = cookbook_versions.cookbook_id
        }

        migrate :CookbookVersionRecord => :CookbookVersion
      end

      include Enumerable

      def initialize(record)
        @skip = true
        @record = record
        @cookbook = ::Cookbook.with_name(@record.cookbook.name).first

        if @cookbook
          if @cookbook.cookbook_versions.find_by(version: @record.version).nil?
            @skip = false
          end
        end
      end

      def each
        return if @skip

        ::CookbookVersion.new(
          description: @record.cookbook.description,
          version: @record.version,
          license: @record.license,
          tarball_file_name: @record.tarball_file_name,
          tarball_content_type: @record.tarball_content_type,
          tarball_file_size: @record.tarball_file_size,
          tarball_updated_at: @record.tarball_updated_at,
          web_download_count: @record.download_count,
          created_at: @record.created_at,
          updated_at: @record.updated_at,
          legacy_id: @record.id,
          cookbook: cookbook
        ).tap do |cookbook_version|
          cookbook_version.record_timestamps = false
          yield cookbook_version
        end
      end
    end
  end
end
