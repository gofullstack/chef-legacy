require 'supermarket/import/configuration'

module Supermarket
  module Import
    class User
      class << self
        extend Configuration

        list_ids_with %{
          SELECT users.id FROM users
          INNER JOIN email_addresses ON email_addresses.user_id = users.id
          WHERE users.deleted_at IS NULL
          AND email_addresses.address != ''
        }

        migrate :UserRecord => :User
      end

      include Enumerable

      def initialize(record)
        @record = record
      end

      def each
        created_at = @record.created_at
        updated_at = @record.updated_at || @record.created_at

        user = ::User.new(
          email: @record.primary_email_address,
          first_name: @record.first_name,
          last_name: @record.last_name,
          created_at: created_at,
          updated_at: updated_at,
          legacy_id: @record.id
        ).tap do |user|
          user.record_timestamps = false

          yield user
        end

        ::Account.new(
          provider: 'chef_oauth2',
          uid: @record.unique_name,
          username: @record.unique_name,
          oauth_token: 'imported'
        ).tap do |account|
          account.record_timestamps = false
          account.user = user

          yield account
        end
      end
    end
  end
end
