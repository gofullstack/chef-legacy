require 'chef/exceptions'
require 'ruby-progressbar'
require 'supermarket/import'

namespace :supermarket do
  imports = [:users, :categories, :cookbooks, :deprecated_cookbooks,
             :cookbook_following, :supported_platforms, :cookbook_dependencies,
             :cookbook_collaboration].map {  |i| "import:#{i}" }
  cullings = [:users, :cookbooks, :cookbook_following, :cookbook_collaboration].
    map { |c| "cull:#{c}" }

  multitask :migrate => imports + cullings + ['amend:cookbooks']

  namespace :import do
    #
    # Convenience method for import task boilerplate. In particular, each
    # import operation is wrapped in an ActiveRecord transaction. If the import
    # raises an error, we rollback the transaction, and log the error message,
    # but the import does not fail.
    #
    # @param title [String] the progress bar title
    # @param importer [Enumerable, #call] that which can iterate over
    #   unimported records, and whose instances respond to +call+
    #
    def import!(title, importer)
      progress_bar = ProgressBar.create(
        title: "Importing: #{title}",
        total: importer.count,
        format: '%t: (%c/%C) |%B|'
      )

      importer.each do |record|
        progress_bar.increment

        ActiveRecord::Base.transaction do
          begin
            importer.new(record).call
          rescue => e
            progress_bar.decrement

            Raven.capture_exception(e)

            if ENV['SUPERMARKET_DEBUG']
              message_header = "#{e.class}: #{e.message}"
              message_body = ([message_header] + e.backtrace).join("\n  ")
              progress_bar.log message_body
            end

            raise ActiveRecord::Rollback
          end
        end
      end

      progress_bar.stop
    rescue => e
      Raven.capture_exception(e)

      raise e
    end

    desc 'Import community cookbook categories'
    task :categories => :environment do
      import! 'Categories', Supermarket::Import::Category
    end

    desc 'Import community site user accounts'
    task :users => :environment do
      import! 'Users', Supermarket::Import::User
    end

    desc 'Import community cookbook records'
    task :cookbooks => [:users, :categories] do
      import! 'Cookbooks', Supermarket::Import::Cookbook
    end

    desc 'Import cookbook deprecation records'
    task :deprecated_cookbooks => :cookbooks do
      import! 'Deprecated Cookbooks', Supermarket::Import::DeprecatedCookbook
    end

    desc 'Import cookbook following records'
    task :cookbook_following => [:cookbooks, :users] do
      import! 'Cookbook Following', Supermarket::Import::Following
    end

    desc 'Import cookbook collaboration records'
    task :cookbook_collaboration => [:cookbooks, :users] do
      import! 'Cookbook Collaboration', Supermarket::Import::Collaboration
    end

    desc 'Import cookbook version supported platforms'
    task :supported_platforms => :cookbooks do
      import! 'Supported Platform Records', Supermarket::Import::PlatformVersion
    end

    desc 'Import cookbook dependency relationships'
    task :cookbook_dependencies => :cookbooks do
      import! 'Cookbook Dependency Relationships',
        Supermarket::Import::CookbookVersionDependencies
    end

    multitask :all => [:users, :categories, :cookbooks, :deprecated_cookbooks,
                       :cookbook_following, :supported_platforms,
                       :cookbook_dependencies, :cookbook_collaboration]
  end
end
