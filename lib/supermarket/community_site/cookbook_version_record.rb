require 'supermarket/community_site/sadequate_record'

module Supermarket
  module CommunitySite
    class CookbookVersionRecord
      class << self
        extend SadequateRecord::Table
        table :cookbook_versions, :CookbookVersionRecord
      end

      extend SadequateRecord::Record
      extend SadequateRecord::HasMany
      extend SadequateRecord::BelongsTo

      fields :id, :cookbook_id, :version, :license, :tarball_file_name,
        :tarball_file_size, :tarball_content_type, :tarball_updated_at,
        :download_count, :created_at, :updated_at

      has_many :platform_versions, :PlatformVersionRecord, :cookbook_version_id
      belongs_to :cookbook, :CookbookRecord, :cookbook_id

      def artifact_path
        if tarball_file_name.include?('.')
          file_name = tarball_file_name
        else
          file_name = tarball_file_name + '.'
        end

        "/community-files.opscode.com/cookbook_versions/tarballs/#{id}/original/#{file_name}"
      end
    end
  end
end
