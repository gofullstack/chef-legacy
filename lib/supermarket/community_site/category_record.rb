require 'supermarket/community_site/sadequate_record'

module Supermarket
  module CommunitySite
    class CategoryRecord
      class << self
        extend SadequateRecord::Table
        table :categories, :CategoryRecord
      end

      extend SadequateRecord::Record

      fields :id, :name
    end
  end
end
