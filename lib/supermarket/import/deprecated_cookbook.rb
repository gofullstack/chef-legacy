module Supermarket
  module Import
    class DeprecatedCookbook
      def self.import(record)
        new(record).call
      end

      def initialize(record)
        @record = record
        @cookbook = ::Cookbook.with_name(@record.name).first!.tap do |c|
          c.record_timestamps = false
        end
      end

      def complete?
        @cookbook.deprecated? && @cookbook.replacement.present?
      end

      def call
        return unless complete?

        replacement = ::Cookbook.with_name(@record.replacement.name).first!

        @cookbook.deprecated = true
        @cookbook.replacement = replacement
        @cookbook.save!
      end
    end
  end
end
