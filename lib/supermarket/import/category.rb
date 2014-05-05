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
        @record = record
      end

      def complete?
        ::Category.with_name(@record.name).count > 0
      end

      def call(force = false)
        if complete?
          return unless force
        end

        ::Category.create!(name: @record.name)
      end
    end
  end
end
