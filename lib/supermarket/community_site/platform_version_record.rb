require 'supermarket/community_site/sadequate_record'

module Supermarket
  module CommunitySite
    class PlatformVersionRecord
      class << self
        extend SadequateRecord::Table
        table :platform_versions, :PlatformVersionRecord
      end

      extend SadequateRecord::Record
      extend SadequateRecord::BelongsTo

      fields :id, :platform, :version, :cookbook_version_id

      belongs_to :cookbook_version, :CookbookVersionRecord, :cookbook_version_id

      def version_constraint
        value = self.version || '>= 0.0.0'

        if value != '>=0.0.0'
          numeric_part = value.split(' ').last

          if numeric_part.size == 1
            value << '.0' # Corrects, e.g., '~> 5' to '~> 5.0'
          end
        else
          value = '>= 0.0.0'
        end

        value
      end
    end
  end
end
