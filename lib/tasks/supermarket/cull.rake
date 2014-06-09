require 'supermarket/import'
require 'ruby-progressbar'

namespace :supermarket do
  namespace :cull do
    def cull!(title, source, destination)
      imported_ids = destination.where.not(legacy_id: nil).pluck(:legacy_id)

      ids_which_still_exist = imported_ids & source.ids
      ids_which_no_longer_exist = imported_ids - ids_which_still_exist

      bar = Supermarket::Import.debug do
        ProgressBar.create(
          title: "Culling: #{title}",
          total: ids_which_no_longer_exist.count,
          format: '%t: (%c/%C) |%B|'
        )
      end

      ids_which_no_longer_exist.each do |legacy_id|
        Supermarket::Import.debug { bar.increment }

        ActiveRecord::Base.transaction do
          begin
            destination.find_by(legacy_id: legacy_id).try(:destroy)
          rescue => e
            Supermarket::Import.debug { bar.decrement }

            Supermarket::Import.report(e) { |m| bar.log(m) }

            raise ActiveRecord::Rollback
          end
        end
      end

      Supermarket::Import.debug { bar.stop }
    end

    desc 'Remove any outdated cookbook followers'
    task :cookbook_following => [:cookbooks, 'supermarket:import:all'] do
      cull!(
        'Cookbook Following',
        Supermarket::Import::Following,
        ::CookbookFollower
      )
    end

    desc 'Remove any outdated cookbook collaborators'
    task :cookbook_collaboration => [:cookbooks, 'supermarket:import:all'] do
      cull!(
        'Cookbook Collaboration',
        Supermarket::Import::Collaboration,
        ::CookbookCollaborator
      )
    end

    desc 'Remove any outdated cookbooks'
    task :cookbooks => [:users, 'supermarket:import:all'] do
      cull!(
        'Cookbooks',
        Supermarket::Import::Cookbook,
        ::Cookbook
      )
    end

    desc 'Remove any outdated users'
    task :users => [:environment, 'supermarket:import:all'] do
      cull!(
        'Users',
        Supermarket::Import::User,
        ::User
      )
    end

    task :all => [:users, :cookbooks, :cookbook_following,
                  :cookbook_collaboration]
  end
end
