require 'supermarket/community_site/sadequate_record'

module Supermarket
  module CommunitySite
    class CollaborationRecord
      class << self
        extend SadequateRecord::Table
        table :collaborations, :CollaborationRecord
      end

      extend SadequateRecord::Record
      extend SadequateRecord::BelongsTo

      fields :id, :user_id, :cookbook_id

      belongs_to :user, :UserRecord, :user_id
      belongs_to :cookbook, :CookbookRecord, :cookbook_id
    end
  end
end
