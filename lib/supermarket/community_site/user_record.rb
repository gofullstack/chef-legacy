require 'supermarket/community_site/sadequate_record'

module Supermarket
  module CommunitySite
    class UserRecord
      class << self
        extend SadequateRecord::Table
        table :users, :UserRecord

        def existing_usernames
          Pool.with do |conn|
            conn.query("SELECT unique_name FROM users WHERE deleted_at IS NULL").to_a
          end.map { |h| h['unique_name'] }
        end

        def imported_usernames
          existing_username_list = existing_usernames.map do |u|
            "'#{u}'"
          end.join(',')

          imported_usernames_query = %{
            SELECT username FROM accounts
            WHERE provider = 'chef_oauth2'
            AND username IN (#{existing_username_list})
          }.squish

          ::Account.connection.query(imported_usernames_query).flatten
        end

        def usernames_to_be_imported
          existing_usernames - imported_usernames
        end

        def count
          usernames_to_be_imported.count
        end

        #
        # Overrides SadequateRecord's +each+ method so that the importer only
        # recieves usernames which are not present in Supermarket. This
        # marginally speeds up the initial import, and drastically speeds up
        # subsequent imports
        #
        def each
          new_usernames = usernames_to_be_imported

          if new_usernames.any?
            slice_divisor = 10 ** (new_usernames.size.to_s.size - 2)
            slice_size = [new_usernames.size / slice_divisor, 1].max

            new_usernames.each_slice(slice_size) do |usernames|
              list = usernames.map { |u| "'#{u}'" }.join(',')
              condition = "WHERE unique_name IN (#{list})"

              query = %{
                SELECT #{sadequate_sanitized_fields.join(',')} FROM users
                #{condition}
                AND deleted_at IS NULL
              }.squish

              Pool.with do |conn|
                conn.query(query).to_a
              end.each do |user_data|
                yield new(user_data)
              end
            end
          end
        end
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
