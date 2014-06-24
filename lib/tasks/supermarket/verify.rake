require 'ruby-progressbar'
require 'supermarket/import'

namespace :supermarket do
  namespace :verify do
    desc 'Verify CookbookVersion tarball data was migrated correctly'
    task :cookbook_versions => [:environment] do
      base_scope = ::CookbookVersion.
        where(dependencies_imported: true).
        where('legacy_id IS NOT ?', nil)

      verification_frequency = 8 # every 3 hours: 24 / 3 = 8
      batch_size = [
        base_scope.count / verification_frequency,
        verification_frequency
      ].max

      batch_scope = base_scope.
        where(verification_state: %w(pending failed)).
        order('verification_state desc, id asc').
        limit(batch_size)

      progress_bar = Supermarket::Import.debug do
        ProgressBar.create(
          title: "Verifying Cookbook Versions",
          total: batch_scope.count,
          format: '%t: (%c/%C) |%B|'
        )
      end

      batch = ::CookbookVersion.where(id: batch_scope.pluck(:id))
      batch.update_all(verification_state: 'in_progress')

      batch.each do |cookbook_version|
        operations = []
        followup = []

        Supermarket::Import.debug { progress_bar.increment }

        begin
          cookbook_version.record_timestamps = false

          record = Supermarket::CommunitySite::CookbookVersionRecord.find(cookbook_version.legacy_id)
          import = Supermarket::Import::CookbookVersionDependencies.new(record).tap(&:readonly!)

          operations = []
          suggestions = import.to_a.group_by(&:class)

          suggested_cookbook_version = Array(suggestions[::CookbookVersion]).first

          if suggested_cookbook_version
            operations << lambda do
              cookbook_version.update_attributes!(
                readme: suggested_cookbook_version.readme,
                readme_extension: suggested_cookbook_version.readme_extension,
                description: suggested_cookbook_version.description
              )
            end
          end

          suggested_dependencies = Array(suggestions[::CookbookDependency]).map do |dep|
            [dep.name, dep.version_constraint]
          end.sort_by(&:first)

          migrated_dependencies = cookbook_version.cookbook_dependencies.map do |dep|
            [dep.name, dep.version_constraint]
          end.sort_by(&:first)

          if migrated_dependencies != suggested_dependencies
            operations << lambda do
              cookbook_version.cookbook_dependencies = []

              suggestions[::CookbookDependency].each do |dep|
                cookbook_version.cookbook_dependencies.create!(
                  name: dep.name,
                  version_constraint: dep.version_constraint,
                  cookbook: dep.cookbook
                )
              end
            end
          end

          operations << lambda do
            cookbook_version.update_attributes!(verification_state: 'succeeded')
          end

          ActiveRecord::Base.transaction do
            begin
              operations.each(&:call)
            rescue => e
              Supermarket::Import.report(e) { |m| progress_bar.log(m) }
              Supermarket::Import.debug { progress_bar.decrement }

              followup << lambda do
                ::CookbookVersion.
                  where(id: cookbook_version.id).
                  update_all(verification_state: 'failed')
              end

              raise ActiveRecord::Rollback
            end
          end
        rescue => e
          Supermarket::Import.report(e) { |m| progress_bar.log(m) }
          Supermarket::Import.debug { progress_bar.decrement }

          followup << lambda do
            ::CookbookVersion.
              where(id: cookbook_version.id).
              update_all(verification_state: 'failed')
          end
        end

        followup.each(&:call)
      end

      Supermarket::Import.debug { progress_bar.stop }
    end
  end
end
