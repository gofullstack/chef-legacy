require 'supermarket/community_site/sadequate_record'

module Supermarket
  module CommunitySite
    class DeprecatedCookbookRecord
      class << self
        extend SadequateRecord::Table
        table :cookbooks, :CookbookRecord
      end

      extend SadequateRecord::Record
      extend SadequateRecord::BelongsTo

      belongs_to :replacement, :CookbookRecord, :replacement_id

      fields :id, :name, :deprecated, :replacement_id
    end
  end
end
