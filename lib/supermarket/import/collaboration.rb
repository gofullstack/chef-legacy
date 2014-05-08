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
          INNER JOIN email_addresses ON email_addresses.user_id = users.id
          WHERE users.deleted_at IS NULL
          AND email_addresses.address != ''
        }

        migrate :CollaborationRecord => :CookbookCollaborator
      end

      include Enumerable

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

      def each
        return if @skip

        ::CookbookCollaborator.new(
          user_id: @user.id,
          cookbook_id: @cookbook.id,
          created_at: @record.created_at,
          updated_at: @record.updated_at,
          legacy_id: @record.id
        ).tap do |cookbook_collaborator|
          cookbook_collaborator.record_timestamps = false

          yield cookbook_collaborator
        end
      end
    end
  end
end
