require 'supermarket/community_site/sadequate_record'

module Supermarket
  module CommunitySite
    class DeprecatedCookbookRecord
      class << self
        extend SadequateRecord::Table
        table :cookbooks, :CookbookRecord

        def each
          query = %{
            SELECT #{sadequate_sanitized_fields.join(',')} FROM cookbooks
            WHERE deprecated = 1
          }

          deprecated_cookbooks = Pool.with do |conn|
            conn.query(query).to_a
          end.each do |cookbook_data|
            yield new(cookbook_data)
          end
        end
      end

      extend SadequateRecord::Record
      extend SadequateRecord::BelongsTo

      belongs_to :replacement, :CookbookRecord, :replacement_id

      fields :id, :name, :deprecated, :replacement_id
    end
  end
end
