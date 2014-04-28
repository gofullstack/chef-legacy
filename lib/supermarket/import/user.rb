module Supermarket
  module Import
    class User
      def self.import(record)
        new(record).call
      end

      def initialize(record)
        @record = record
      end

      def complete?
        importing_deleted_record? || already_imported?
      end

      def call(force = false)
        if complete?
          return unless force
        end

        account = ::Account.new(
          provider: 'chef_oauth2',
          uid: @record.unique_name,
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

      private

      def already_imported?
        ::Account.
          where(provider: 'chef_oauth2', uid: @record.unique_name).
          joins(:user).
          count > 0
      end

      def importing_deleted_record?
        !!@record.deleted_at
      end

    end
  end
end
