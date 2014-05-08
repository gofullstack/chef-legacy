require 'supermarket/import/configuration'

module Supermarket
  module Import
    class Category
      class << self
        extend Configuration

        list_ids_with "SELECT categories.id FROM categories"

        migrate :CategoryRecord => :Category
      end

      def initialize(record)
        @skip = true
        @record = record

        if Category.with_name(@record.name).count == 0
          @skip = false
        end
      end

      def call
        return if @skip

        ::Category.create!(name: @record.name)
      end
    end
  end
end
