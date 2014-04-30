require 'supermarket/community_site/sadequate_record'

module Supermarket
  module CommunitySite
    class FollowingRecord
      class << self
        extend SadequateRecord::Table
        table :followings, :FollowingRecord
      end

      extend SadequateRecord::Record
      extend SadequateRecord::BelongsTo

      fields :id, :user_id, :followable_id, :followable_type, :created_at,
        :updated_at

      belongs_to :user, :UserRecord, :user_id
      # NOTE: punting on polymorphic following for now. As such, the behavior
      # of FollowingRecord#cookbook is undefined unless +followable_type ==
      # 'Cookbook'+
      belongs_to :cookbook, :CookbookRecord, :followable_id

      def cookbook?
        'Cookbook' == followable_type
      end
    end
  end
end
