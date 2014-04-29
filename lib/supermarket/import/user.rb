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
        account = ::Account.new(
          provider: 'chef_oauth2',
          uid: @record.unique_name,
          username: @record.unique_name,
          oauth_token: 'imported'
        )

        user = ::User.new(
          email: @record.primary_email_address,
          first_name: @record.first_name,
          last_name: @record.last_name
        )

        account.user = user
        account.save!
      end
    end
  end
end
