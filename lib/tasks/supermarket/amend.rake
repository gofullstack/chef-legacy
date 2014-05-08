require 'ruby-progressbar'
require 'supermarket/community_site'

namespace :supermarket do
  namespace :amend do
    desc 'Update imported cookbook data'
    task :cookbooks => ['supermarket:cull:all', :environment] do
      begin
        bar = ProgressBar.create(
          title: "Amending Cookbook Data",
          total: ::Cookbook.count,
          format: '%t: (%c/%C) |%B|'
        )

        ::Cookbook.where.not(legacy_id: nil).find_in_batches do |batch|
          batch.each do |cookbook|
            ActiveRecord::Base.transaction do
              begin
                id = cookbook.legacy_id
                record = Supermarket::CommunitySite::CookbookRecord.find(id)

                if record && record.updated_at.utc > cookbook.updated_at.utc
                  cookbook.assign_attributes(
                    category: record.supermarket_category,
                    owner: record.supermarket_owner,
                    source_url: record.sanitized_external_url.to_s,
                    updated_at: record.updated_at
                  )
                  cookbook.record_timestamps = false
                  cookbook.save!
                end

                bar.increment
              rescue => e
                bar.decrement

                Raven.capture_exception(e)

                if ENV['SUPERMARKET_DEBUG']
                  message_header = "#{e.class}: #{e.message}"
                  message_body = ([message_header] + e.backtrace).join("\n  ")
                  bar.log message_body
                end

                raise ActiveRecord::Rollback
              end
            end
          end
        end
      rescue => e
        Raven.capture_exception(e)

        raise e
      end
    end
  end
end
