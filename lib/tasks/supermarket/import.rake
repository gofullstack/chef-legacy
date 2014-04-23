require 'mysql2'
require 'ruby-progressbar'

DB = Mysql2::Client.new(
  host: ENV['LEGACY_DB_HOST'] || 'localhost',
  username: ENV['LEGACY_DB_USERNAME'] || 'root',
  database: ENV['LEGACY_DB_DATABASE'] || 'opscode_community_site_production'
)

namespace :supermarket do
  namespace :import do
    desc 'Import community cookbook categories'
    task :categories => :environment do
      puts "Importing Categories"

      progress_bar = ProgressBar.create(total: categories.count)

      import_categories(progress_bar)
    end

    desc 'Import community cookbook records'
    task :cookbooks => :categories do
      puts "Importing Cookbook Data"

      progress_bar = ProgressBar.create(total: cookbooks.count)

      import_cookbooks_with_versions_and_platforms(progress_bar)
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
  @categories ||= DB.query('select * from categories').to_a
end

def cookbooks
  @cookbooks ||= DB.query('select * from cookbooks').to_a
end

def cookbook_versions
  @cookbook_versions ||= DB.query('select * from cookbook_versions').to_a
end

def platform_versions
  @platform_versions ||= DB.query('select * from platform_versions').to_a
end
