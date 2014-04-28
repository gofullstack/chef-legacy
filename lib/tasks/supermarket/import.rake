require 'chef/exceptions'
require 'ruby-progressbar'
require 'supermarket/community_site'
require 'supermarket/import'

namespace :supermarket do
  namespace :import do
    #
    # Convenience method for import task boilerplate. In particular, each
    # import operation is wrapped in an ActiveRecord transaction. If the import
    # raises an error, we rollback the transaction, and log the error message,
    # but the import does not fail.
    #
    # @param title [String] the progress bar title
    # @param type [Enumerable] that which enumerates the existing community
    #   site data
    # @param importer [.import] that which imports a single record from the
    #   existing community site
    #
    def import!(title, type, importer)
      progress_bar = ProgressBar.create(title: title, total: type.count)

      type.each do |record|
        progress_bar.increment

        ActiveRecord::Base.transaction do
          begin
            importer.import(record)
          rescue => e
            message_header = "#{e.class}: #{e.message}"
            message_body = ([message_header] + e.backtrace).join("\n  ")
            progress_bar.log message_body

            raise ActiveRecord::Rollback
          end
        end
      end
    end

    desc 'Import community cookbook categories'
    task :categories => :environment do
      import! 'Categories',
        Supermarket::CommunitySite::CategoryRecord,
        Supermarket::Import::Category
    end

    desc 'Import community site user accounts'
    task :users => :environment do
      import! 'Users',
        Supermarket::CommunitySite::UserRecord,
        Supermarket::Import::User
    end

    desc 'Import community cookbook records'
    task :cookbooks => :categories do
      import! 'Cookbooks',
        Supermarket::CommunitySite::CookbookRecord,
        Supermarket::Import::Cookbook
    end

    desc 'Import cookbook following records'
    task :cookbook_following => [:cookbooks, :users] do
      import! 'Cookbook Following',
        Supermarket::CommunitySite::FollowingRecord,
        Supermarket::Import::Following
    end

    desc 'Import cookbook version supported platforms'
    task :supported_platforms => :cookbooks do
      import! 'Supported Platform Records',
        Supermarket::CommunitySite::PlatformVersionRecord,
        Supermarket::Import::PlatformVersion
    end

    desc 'Import cookbook dependency relationships'
    task :cookbook_dependencies => :cookbooks do
      import! 'Cookbook Dependency Relationships',
        Supermarket::CommunitySite::CookbookVersionRecord,
        Supermarket::Import::CookbookVersionDependencies
    end
  end
end
