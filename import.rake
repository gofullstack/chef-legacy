require 'csv'

namespace :legacy do
  desc 'Import legacy community site data from CSV files.'
  task :import => :environment do
    import_categories
    import_cookbooks_with_versions_and_platforms
  end
end

#
# Parses categories.csv and creates a new Category
# for every row.
#
def import_categories
  categories = parse_csv('categories.csv')

  categories.each do |row|
    row = row.to_hash
    Category.create!(name: row['name'])
  end
end

#
# Parses cookbooks.csv, cookbook_versions.csv and
# platform_versions.csv Then the cookbooks and their dependencies
# (Category and CookbookVersion) are associated/created. The cookbook
# Category is found by using a column in each cookbook row named category_name
# derived from joining the categories and cookbooks table from the original
# legacy database. For each cookbook row the corresponding cookbook version
# rows are found by selecting rows from cookbook_versions.csv
# where the column cookbook_id matches the current cookbook row id.
# Each instance of CookbookVersion is created with a hard coded
# tarball_content_type of application/x-gzip because of inconsistencies
# in the legacy database application/x-gzip is the desired content type
# as all of the legacy tarballs are tgz files. For each CookbookVersion
# the supported platforms are created and associated by finding the corresponding
# platform version rows by matching the current cookbook version row id with the
# platform version row id.
#
def import_cookbooks_with_versions_and_platforms
  cookbooks = parse_csv('cookbooks.csv')
  cookbook_versions = parse_csv('cookbook_versions.csv')
  platform_versions = parse_csv('platform_versions.csv')

  cookbooks.each do |row|
    row = row.to_hash
    category = Category.with_name(row['category_name']).first!

    if URI(row['external_url']).is_a?(URI::Generic)
      well_formed_external_url = ('http://' + row['external_url'])
    end

    cookbook = Cookbook.new(
      name: row['name'],
      maintainer: 'john@example.com',
      description: row['description'],
      category: category,
      source_url: well_formed_external_url || row['external_url'],
      download_count: row['download_count'],
      deprecated: row['deprecated']
    )

    cookbook_versions.
      select { |v| v.to_hash['cookbook_id'] == row['id'] }.
      each do |version|

      version = version.to_hash

      cookbook_version = CookbookVersion.new(
        version: version['version'],
        license: version['license'],
        tarball_file_name: version['tarball_file_name'],
        tarball_content_type: 'application/x-gzip',
        tarball_file_size: version['tarball_file_size'],
        tarball_updated_at: version['tarball_updated_at'],
        download_count: version['download_count'],
        cookbook: cookbook
      )

      platform_versions.
        select { |p| p.to_hash['cookbook_version_id'] == version['id'] }.
        each do |platform|

        platform = platform.to_hash

        supported_platform = SupportedPlatform.new(
          name: platform['platform'],
          version_constraint: platform['version'],
          cookbook_version: cookbook_version
        )

        cookbook_version.supported_platforms << supported_platform
      end

      cookbook.cookbook_versions << cookbook_version
    end

    cookbook.save!
  end
end

#
# Parses a given CSV file found in the data directory.
#
def parse_csv(filename)
  CSV.parse(File.read(File.join(File.dirname(__FILE__), "data/#{filename}")), headers: true)
end
