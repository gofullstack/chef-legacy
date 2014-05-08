File.dirname(__FILE__).tap do |supermarket|
  Dir[File.join(supermarket, 'import', '*.rb')].map do |file|
    file.split(File::SEPARATOR).last.split('.').first
  end.each do |name|
    require "supermarket/import/#{name}"
  end
end

require 'supermarket/community_site'

module Supermarket
  module Import
    def self.report(e)
      Raven.capture_exception(e)

      if ENV['SUPERMARKET_DEBUG']
        message_header = "#{e.class}: #{e.message}"
        message_body = ([message_header] + e.backtrace).join("\n  ")

        yield message_body
      end
    end
  end
end
