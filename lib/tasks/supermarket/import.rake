require 'chef/version_constraint'
require 'chef/exceptions'
require 'mysql2'
require 'net/http'
require 'ruby-progressbar'
require 'supermarket/import/database_configuration'
require 'tempfile'

namespace :supermarket do
  namespace :import do
    desc 'Import community cookbook categories'
    task :categories => [:connect, :environment] do
      progress_bar = ProgressBar.create(
        title: 'Categories',
        total: categories.count
      )

      import_categories(progress_bar)
    end

    desc 'Import community cookbook records'
    task :cookbooks => :categories do
      progress_bar = ProgressBar.create(
        title: 'Cookbooks',
        total: cookbooks.count
      )

      import_cookbooks_with_versions_and_platforms(progress_bar)
    end

    desc 'Import cookbook dependency relationships'
    task :cookbook_dependencies => :cookbooks do
      progress_bar = ProgressBar.create(
        title: 'Cookbook Dependency Relationships',
        total: cookbook_versions.count
      )

      import_cookbook_dependency_relationships(progress_bar)
    end

    task :connect do
      Supermarket::Import::DB = Mysql2::Client.new(
        Supermarket::Import::DatabaseConfiguration.community_site.to_h
      )
    end
  end
end

def artifact_path(cookbook_version)
  id = cookbook_version['id']
  tarball_file_name = cookbook_version['tarball_file_name']

  unless tarball_file_name.include?('.')
    tarball_file_name << '.'
  end

  "/community-files.opscode.com/cookbook_versions/tarballs/#{id}/original/#{tarball_file_name}"
end

def import_cookbook_dependency_relationships(progress_bar)
  cookbooks.each do |row|
    cookbook_versions.select do |cookbook_version_row|
      cookbook_version_row['cookbook_id'] == row['id']
    end.each do |cookbook_version_row|
      progress_bar.increment

      version = cookbook_version_row['version']

      cookbook = Cookbook.with_name(row['name']).first!
      cookbook_version = cookbook.cookbook_versions.find_by!(version: version)

      next if cookbook_version.dependencies_imported?

      tarball = Tempfile.new(cookbook_version.id.to_s, 'tmp').tap do |tb|
        tb.set_encoding 'ASCII-8BIT'
      end

      Net::HTTP.start('s3.amazonaws.com', 80) do |http|
        request = Net::HTTP::Get.new(artifact_path(cookbook_version_row))

        http.request(request) do |response|
          response.read_body do |chunk|
            tarball.write(chunk)
          end
        end
      end

      tarball.rewind

      params = CookbookUpload::Parameters.new(cookbook: '{}', tarball: tarball)
      dependencies = params.metadata.dependencies

      ActiveRecord::Base.transaction do
        existing_cookbooks = Cookbook.where(name: dependencies.keys)
        dependencies.each do |name, version_constraint|
          begin
            safe_version_constraint = Chef::VersionConstraint.new(version_constraint).to_s
          rescue Chef::Exceptions::InvalidVersionConstraint
            progress_bar.log "#{cookbook.name} #{cookbook_version.version}: #{version_constraint} not valid"
            raise ActiveRecord::Rollback
          end

          cookbook_version.cookbook_dependencies.create!(
            name: name,
            version_constraint: safe_version_constraint,
            cookbook: existing_cookbooks.find { |c| c.name == name }
          )
        end

        cookbook_version.update_attribute(:dependencies_imported, true)
      end
    end
  end
end

def import_categories(progress_bar)
  categories.each do |row|
    progress_bar.increment

    next if Category.with_name(row['name']).first

    Category.create!(name: row['name'])
  end
end

def import_cookbooks_with_versions_and_platforms(progress_bar)
  cookbooks.each do |row|
    progress_bar.increment

    next if Cookbook.with_name(row['name']).first

    category_name = categories.find do |category|
      category['id'] == row['category_id']
    end.fetch('name')

    category = Category.with_name(category_name).first!

    if row['external_url'].to_s.strip.size > 0
      external_url = URI(row['external_url'])

      unless external_url.is_a?(URI::HTTP) || external_url.is_a?(URI::HTTPS)
        external_url = URI('http://' + row['external_url'])
      end
    else
      external_url = nil
    end

    cookbook = Cookbook.new(
      name: row['name'],
      maintainer: 'john@example.com',
      description: row['description'],
      category: category,
      source_url: external_url.to_s,
      download_count: row['download_count'],
      deprecated: row['deprecated'],
    )

    build_cookbook_versions(row['id']).each do |cookbook_version|
      cookbook_version.cookbook = cookbook
      cookbook.cookbook_versions << cookbook_version
    end

    cookbook.save!
  end
end

def build_cookbook_versions(cookbook_id)
  cookbook_versions.
    select { |v| v['cookbook_id'] == cookbook_id }.
    map do |version|

    CookbookVersion.new(
      version: version['version'],
      license: version['license'],
      tarball_file_name: version['tarball_file_name'],
      tarball_content_type: 'application/x-gzip',
      tarball_file_size: version['tarball_file_size'],
      tarball_updated_at: version['tarball_updated_at'],
      download_count: version['download_count'],
    ).tap do |cookbook_version|
      build_supported_platforms(version['id']).each do |supported_platform|
        supported_platform.cookbook_version = cookbook_version
        cookbook_version.supported_platforms << supported_platform
      end
    end
  end
end

def build_supported_platforms(cookbook_version_id)
  platform_versions.
    select { |p| p['cookbook_version_id'] == cookbook_version_id }.
    map do |platform|

    version_constraint = platform['version'] || '>= 0.0.0'

    if version_constraint != '>=0.0.0'
      numeric_part = version_constraint.split(' ').last

      if numeric_part.size == 1
        version_constraint << '.0' # Corrects, e.g., '~> 5' to '~> 5.0'
      end
    else
      version_constraint = '>= 0.0.0'
    end

    SupportedPlatform.new(
      name: platform['platform'],
      version_constraint: version_constraint
    )
  end
end

def categories
  @categories ||= all('categories')
end

def cookbooks
  @cookbooks ||= all('cookbooks')
end

def cookbook_versions
  @cookbook_versions ||= all('cookbook_versions')
end

def platform_versions
  @platform_versions ||= all('platform_versions')
end

def all(table)
  Supermarket::Import::DB.query("select * from #{table}").to_a
end
