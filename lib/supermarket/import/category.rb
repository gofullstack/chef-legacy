module Supermarket
  module Import
    class Category
      def self.import(record)
        new(record).call
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
