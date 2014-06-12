File.dirname(__FILE__).tap do |supermarket|
  Dir[File.join(supermarket, 'community_site', '*_record.rb')].map do |file|
    file.split(File::SEPARATOR).last.split('.').first
  end.each do |record_type|
    require "supermarket/community_site/#{record_type}"
  end
end

require 'connection_pool'
require 'mysql2'
require 'supermarket/community_site/database_configuration'

module Supermarket
  module CommunitySite
    def self.pool
      @pool || connect!
    end

    def self.connect!
      @pool = ConnectionPool.new(size: 5) do
        Mysql2::Client.new(DatabaseConfiguration.community_site.to_h)
      end
    end

    def self.disconnect!
      return if @pool.nil?

      @pool.shutdown { |connection| connection.close }
      @pool = nil
    end
  end
end
