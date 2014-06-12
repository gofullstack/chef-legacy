module Supermarket
  module Import
    module Configuration
      def list_ids_with(query)
        define_method(:ids) do
          CommunitySite.pool.with do |conn|
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
          missing_ids.each do |missing_id|
            record = source_type.find(missing_id)

            if record
              block.call(record)
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
