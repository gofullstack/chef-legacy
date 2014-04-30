module Supermarket
  module Import
    class User
      def self.import(record)
        new(record).call
      end

      def initialize(record)
        @record = record
      end

      def call
        created_at = @record.created_at
        updated_at = @record.updated_at || @record.created_at

        account = ::Account.new(
          provider: 'chef_oauth2',
          uid: @record.unique_name,
          username: @record.unique_name,
          oauth_token: 'imported'
        ).tap { |a| a.record_timestamps = false }

        user = ::User.new(
          email: @record.primary_email_address,
          first_name: @record.first_name,
          last_name: @record.last_name,
          created_at: created_at,
          updated_at: updated_at
        ).tap { |u| u.record_timestamps = false }

        account.user = user
        account.save!
      end
    end
  end
end
