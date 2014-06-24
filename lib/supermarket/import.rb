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
    def self.debug
      yield if ENV['SUPERMARKET_DEBUG']
    end

    def self.report(e)
      raven_options = {}

      if e.respond_to?(:record) && e.record.is_a?(::CookbookVersion)
        if e.record.errors[:tarball_content_type]
          raven_options[:extra] = {
            tarball_content_type: e.record.tarball_content_type
          }
        end
      end

      if e.is_a?(CookbookVersionDependencies::UnableToProcessTarball)
        raven_options[:extra] = {
          cookbook_name: e.cookbook_name,
          cookbook_version: e.cookbook_version,
          messages: e.errors.full_messages.join('; ')
        }
      end

      Raven.capture_exception(e, raven_options)

      debug do
        message_header = "#{e.class}: #{e.message}\n  #{raven_options.inspect}"

        relevant_backtrace = e.backtrace.select do |line|
          line.include?('supermarket') || line.include?('chef-legacy')
        end

        message_body = ([message_header] + relevant_backtrace).join("\n  ")

        yield message_body
      end
    end
  end
end
