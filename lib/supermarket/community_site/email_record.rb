require 'supermarket/community_site/sadequate_record'

module Supermarket
  module CommunitySite
    class EmailRecord
      class << self
        extend SadequateRecord::Table
        table :email_addresses, :EmailRecord
      end

      extend SadequateRecord::Record

      fields :id, :user_id, :address, :verified, :primary
    end
  end
end
