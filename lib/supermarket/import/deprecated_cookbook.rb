require 'supermarket/import/configuration'

module Supermarket
  module Import
    class DeprecatedCookbook
      class << self
        extend Configuration

        list_ids_with %{
          SELECT cookbooks.id FROM cookbooks
          INNER JOIN cookbooks AS replacements ON replacements.id = cookbooks.replacement_id
          WHERE cookbooks.deprecated = 1
        }

        migrate :DeprecatedCookbookRecord => :Cookbook

        def imported_legacy_ids
          ::Cookbook.where(deprecated: true, legacy_id: ids).pluck(:legacy_id)
        end
      end

      def initialize(record)
        @skip = true
        @record = record
        @cookbook = ::Cookbook.with_name(@record.name).first
        @replacement = ::Cookbook.with_name(@record.replacement.name).first

        if @cookbook && @replacement
          @skip = false
        end
      end

      def call
        return if @skip

        @cookbook.deprecated = true
        @cookbook.replacement = @replacement
        @cookbook.record_timestamps = false
        @cookbook.save!
      end
    end
  end
end
