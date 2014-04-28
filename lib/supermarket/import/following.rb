module Supermarket
  module Import
    class Following
      def self.import(record)
        new(record).call
      end

      def initialize(record)
        @record = record
      end

      def complete?
        if @record.cookbook?
          imported?
        else
          true
        end
      end

      def call(force = false)
        if complete?
          return unless force
        end

        ::CookbookFollower.create!(
          user_id: user.id,
          cookbook_id: cookbook.id
        )
      end

      private

      def imported?
        ::CookbookFollower.where(
          user_id: user.id,
          cookbook_id: cookbook.id
        ).count > 0
      end

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
        old_user = @record.user

        ::Account.where(
          provider: 'chef_oauth2',
          username: old_user.unique_name
        ).first!.user
      end
    end
  end
end
