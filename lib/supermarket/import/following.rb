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
        @record = record
        @old_user = record.user
      end

      def call
        ::CookbookFollower.new(
          user_id: user.id,
          cookbook_id: cookbook.id,
          created_at: @record.created_at,
          updated_at: @record.updated_at,
          legacy_id: @record.id
        ).tap do |follower|
          follower.record_timestamps = false
          follower.save!
        end
      end

      private

      def cookbook
        @cookbook ||= fetch_cookbook
      end

      def user
        @user ||= fetch_user
      end

      def fetch_cookbook
        old_cookbook = @record.cookbook

        ::Cookbook.with_name(old_cookbook.name).first!
      end

      def fetch_user
        ::Account.where(
          provider: 'chef_oauth2',
          username: @old_user.unique_name
        ).first!.user
      end
    end
  end
end
