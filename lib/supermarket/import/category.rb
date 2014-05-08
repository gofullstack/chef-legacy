require 'supermarket/import/configuration'

module Supermarket
  module Import
    class Category
      class << self
        extend Configuration

        list_ids_with "SELECT categories.id FROM categories"

        migrate :CategoryRecord => :Category
      end

      include Enumerable

      def initialize(record)
        @skip = true
        @record = record

        if ::Category.with_name(@record.name).count == 0
          @skip = false
        end
      end

      def each
        return if @skip

        yield ::Category.new(name: @record.name)
      end
    end
  end
end
