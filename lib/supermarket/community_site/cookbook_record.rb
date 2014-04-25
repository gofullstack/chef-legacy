require 'supermarket/community_site/sadequate_record'

module Supermarket
  module CommunitySite
    class CookbookRecord
      class << self
        extend SadequateRecord::Table
        table :cookbooks, :CookbookRecord
      end

      extend SadequateRecord::Record
      extend SadequateRecord::HasMany
      extend SadequateRecord::BelongsTo

      fields :id, :name, :description, :download_count, :external_url,
        :deprecated, :category_id

      has_many :cookbook_versions, :CookbookVersionRecord, :cookbook_id
      belongs_to :category, :CategoryRecord, :category_id

      def sanitized_external_url
        if external_url.to_s.strip.size > 0
          if http_external_url? || https_external_url?
            URI(external_url)
          else
            URI('http://' + external_url)
          end
        end
      end

      private

      def http_external_url?
        URI(external_url).is_a?(URI::HTTP)
      end

      def https_external_url?
        URI(external_url).is_a?(URI::HTTPS)
      end
    end
  end
end
