require 'connection_pool'
require 'mysql2'
require 'supermarket/community_site/database_configuration'

module Supermarket
  module CommunitySite
    Pool = ConnectionPool.new(size: 5) do
      Mysql2::Client.new(DatabaseConfiguration.community_site.to_h)
    end
  end
end
