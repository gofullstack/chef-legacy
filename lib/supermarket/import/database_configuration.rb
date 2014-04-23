require 'uri'

module Supermarket
  module Import
    class DatabaseConfiguration
      def self.community_site
        url = ENV.fetch('COMMUNITY_SITE_DATABASE_URL') do
          'mysql://root:@127.0.0.1:3306/opscode_community_site_production'
        end

        new(url)
      end

      def initialize(url)
        @url = URI(url)
      end

      def to_h
        {
          host: component(:host),
          port: component(:port),
          username: component(:user),
          password: component(:password),
          database: ->(url) { component(:path).call(url)[1..-1] }
        }.reduce({}) do |configuration, (key, value)|
          configuration.update(key => value.call(@url))
        end
      end

      private

      def component(name)
        ->(whole) { whole.method(name).call() }
      end
    end
  end
end
