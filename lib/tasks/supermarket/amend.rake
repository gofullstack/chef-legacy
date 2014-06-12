require 'ruby-progressbar'
require 'supermarket/community_site'

namespace :supermarket do
  namespace :amend do
    desc 'Update imported cookbook data'
    task :cookbooks => ['supermarket:cull:all', :environment] do
      bar = Supermarket::Import.debug do
        ProgressBar.create(
          title: "Amending Cookbook Data",
          total: ::Cookbook.count,
          format: '%t: (%c/%C) |%B|'
        )
      end

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

            Supermarket::Import.debug { bar.increment }
          rescue => e
            Supermarket::Import.debug { bar.decrement }

            Supermarket::Import.report(e) { |m| bar.log(m) }
          end
        end
      end
    end

    desc 'Update Users registered before the migration'
    task :users => ['supermarket:cull:all', :environment] do
      base_scope = ::Account.for('chef_oauth2').joins(:user).where('legacy_id IS ?', nil)

      bar = Supermarket::Import.debug do
        ProgressBar.create(
          title: "Amending Account Data",
          total: base_scope.count,
          format: '%t: (%c/%C) |%B|'
        )
      end

      base_scope.find_each do |account|
        begin
          legacy_user = Supermarket::CommunitySite::UserRecord.query(
            unique_name: account.username
          ).first

          if legacy_user
            user = account.user
            user.record_timestamps = false
            user.legacy_id = legacy_user.id
            user.save!
          end

          Supermarket::Import.debug { bar.increment }
        rescue => e
          Supermarket::Import.debug { bar.decrement }

          Supermarket::Import.report(e) { |m| bar.log(m) }
        end
      end
    end
  end
end
