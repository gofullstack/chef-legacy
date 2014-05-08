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

              Supermarket::Import.report(e) { |m| bar.log(m) }
            end
          end
        end
      rescue => e
        Supermarket::Import.report(e) { |m| bar.log(m) }

        raise e
      end
    end
  end
end
