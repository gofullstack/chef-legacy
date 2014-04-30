module Supermarket
  module Import
    class Following
      def self.import(record)
        new(record).call
      end

      def initialize(record)
        @record = record
        @old_user = record.user

        if @old_user.nil?
          @skip = true
        end
      end

      def complete?
        return true if @skip

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

        ::CookbookFollower.new(
          user_id: user.id,
          cookbook_id: cookbook.id,
          created_at: @record.created_at,
          updated_at: @record.updated_at
        ).tap do |follower|
          follower.record_timestamps = false
          follower.save!
        end
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
        ::Account.where(
          provider: 'chef_oauth2',
          username: @old_user.unique_name
        ).first!.user
      end
    end
  end
end
