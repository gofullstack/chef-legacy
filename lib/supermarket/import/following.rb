require 'supermarket/import/configuration'

module Supermarket
  module Import
    class Following
      class << self
        extend Configuration

        list_ids_with %{
          SELECT followings.id
          FROM followings
          INNER JOIN cookbooks ON cookbooks.id = followings.followable_id
          INNER JOIN users ON users.id = followings.user_id
          INNER JOIN email_addresses ON email_addresses.user_id = users.id
          WHERE users.deleted_at IS NULL
          AND email_addresses.address != ''
          AND followable_type='Cookbook'
        }

        migrate :FollowingRecord => :CookbookFollower
      end

      def initialize(record)
        @skip = true
        @record = record
        @cookbook = ::Cookbook.with_name(@record.cookbook.name).first

        if @cookbook
          account = ::Account.
            where(provider: 'chef_oauth2', username: record.user.unique_name).
            first

          if account && account.user
            @skip = false
            @user = account.user
          end
        end
      end

      def call
        return if @skip

        ::CookbookFollower.new(
          user_id: @user.id,
          cookbook_id: @cookbook.id,
          created_at: @record.created_at,
          updated_at: @record.updated_at,
          legacy_id: @record.id
        ).tap do |follower|
          follower.record_timestamps = false
          follower.save!
        end
      end

      private

    end
  end
end
