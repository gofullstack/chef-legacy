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
        :deprecated, :replacement_id, :category_id, :maintainer_id,
        :created_at, :updated_at

      has_many :cookbook_versions, :CookbookVersionRecord, :cookbook_id
      belongs_to :category, :CategoryRecord, :category_id
      belongs_to :maintainer, :UserRecord, :maintainer_id
      belongs_to :replacement, :CookbookRecord, :replacement_id

      def sanitized_external_url
        if external_url.to_s.strip.size > 0
          if http_external_url? || https_external_url?
            URI(external_url)
          else
            URI('http://' + external_url)
          end
        end
      end

      def supermarket_owner
        username = maintainer.unique_name

        ::Account.for('chef_oauth2').with_username(username).first!.user
      end

      def supermarket_category
        ::Category.with_name(category.name).first!
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
