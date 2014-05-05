require 'supermarket/community_site/pool'

module Supermarket
  module Import
    module Configuration
      def basic_import(record_type_name)
        define_method(:record_type) do
          Supermarket::CommunitySite.const_get(record_type_name)
        end

        define_method(:each) do |&block|
          record_type.each(&block)
        end

        define_method(:count) do
          record_type.count
        end

        define_method(:ids) do
          CommunitySite::Pool.with do |conn|
            conn.query("SELECT id FROM #{record_type.sadequate_table_name}")
          end.to_a.map { |result| result['id'].to_i }
        end
      end

      def list_ids_with(query)
        define_method(:ids) do
          CommunitySite::Pool.with do |conn|
            conn.query(query)
          end.to_a.map { |result| result['id'].to_i }
        end
      end

      def migrate(pathway)
        source = pathway.keys.first
        destination = pathway[source]

        define_method(:source_type) do
          Supermarket::CommunitySite.const_get(source)
        end

        define_method(:destination_type) do
          Kernel.const_get(destination)
        end

        define_method(:each) do |&block|
          query = %{
            SELECT #{source_type.sadequate_sanitized_field_list}
            FROM #{source_type.sadequate_table_name}
            WHERE id = %d
          }.squish

          missing_ids.each do |missing_id|
            record_data = CommunitySite::Pool.with do |conn|
              conn.query(query % [missing_id])
            end.first

            if record_data
              block.call(source_type.new(record_data))
            end
          end
        end

        define_method(:imported_legacy_ids) do
          destination_type.where(legacy_id: ids).pluck(:legacy_id)
        end

        define_method(:missing_ids) do
          if destination_type.attribute_names.include?('legacy_id')
            community_site_ids = ids

            common_ids = community_site_ids & imported_legacy_ids

            community_site_ids - common_ids
          else
            ids
          end
        end

        define_method(:count) do
          missing_ids.count
        end

        include Enumerable
      end
    end
  end
end
