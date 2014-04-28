require 'supermarket/community_site/sadequate_record'

module Supermarket
  module CommunitySite
    class ProfileRecord
      class << self
        extend SadequateRecord::Table
        table :profiles, :ProfileRecord
      end

      extend SadequateRecord::Record

      fields :id, :user_id, :first_name, :last_name
    end
  end
end
