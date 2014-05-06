require 'supermarket/community_site/sadequate_record'

module Supermarket
  module CommunitySite
    class UserRecord
      class << self
        extend SadequateRecord::Table
        table :users, :UserRecord
      end

      extend SadequateRecord::Record
      extend SadequateRecord::HasMany
      extend SadequateRecord::HasOne

      fields :id, :unique_name, :deleted_at, :created_at, :updated_at

      has_many :email_addresses, :EmailRecord, :user_id
      has_one :profile, :ProfileRecord, :user_id

      def primary_email_address
        primary = email_addresses.find(&:primary)

        if primary
          primary.address
        end
      end

      def first_name
        if profile
          profile.first_name
        end
      end

      def last_name
        if profile
          profile.last_name
        end
      end
    end
  end
end
