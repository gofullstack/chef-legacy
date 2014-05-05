require 'supermarket/import/configuration'

module Supermarket
  module Import
    class Collaboration
      class << self
        extend Configuration

        list_ids_with %{
          SELECT collaborations.id
          FROM collaborations
          INNER JOIN users ON users.id = collaborations.user_id
          INNER JOIN cookbooks ON cookbooks.id = collaborations.cookbook_id
        }

        migrate :CollaborationRecord => :CookbookCollaborator
      end

      def initialize(record)
        @record = record
        @old_user = record.user
      end

      def call
        ::CookbookCollaborator.new(
          user_id: user.id,
          cookbook_id: cookbook.id,
          created_at: @record.created_at,
          updated_at: @record.updated_at,
          legacy_id: @record.id
        ).tap do |cookbook_collaborator|
          cookbook_collaborator.record_timestamps = false
          cookbook_collaborator.save!
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
