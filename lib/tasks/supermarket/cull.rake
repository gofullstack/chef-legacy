require 'supermarket/community_site'
require 'ruby-progressbar'

namespace :supermarket do
  namespace :cull do
    def cull!(title, source, destination)
      imported_ids = destination.where.not(legacy_id: nil).pluck(:legacy_id)

      ids_which_still_exist = imported_ids & source.ids
      ids_which_no_longer_exist = imported_ids - ids_which_still_exist

      bar = ProgressBar.create(
        title: "Culling: #{title}",
        total: ids_which_no_longer_exist.count,
        format: '%t: (%c/%C) |%B|'
      )

      ids_which_no_longer_exist.each do |legacy_id|
        bar.increment

        begin
          destination.find_by!(legacy_id: legacy_id).destroy
        rescue => e
          bar.decrement

          Raven.capture_exception(e)

          message_header = "#{e.class}: #{e.message}"
          message_body = ([message_header] + e.backtrace).join("\n  ")
          bar.log message_body
        end
      end

      bar.stop
    rescue => e
      Raven.capture_exception(e)
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

    multitask :all => [:users, :cookbooks, :cookbook_following,
                       :cookbook_collaboration]
  end
end
