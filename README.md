## Chef Legacy

Chef Legacy is a rake task that aids in the data migration from the old [Opscode Community Site](community.opscode.com)
to the new [Supermarket](https://github.com/opscode/supermarket) community site. Chef Legacy is intended to be run from
within Supermarket but has been broken out into its own project as it has little use beyond the initial data migration.

## Installation

In your Gemfile:

```ruby
gem 'chef-legacy', github: 'gofullstack/chef-legacy'
```

## Configuration

The data import connects to the old MySQL database. The default configuration should be suitable for an out-of-the-box MySQL server running locally, which has had an `opscode_community_site_production` database created, and filled with an SQL dump of the production database.

* `ENV['LEGACY_DB_HOST']` defaults to `localhost`
* `ENV['LEGACY_DB_USERNAME']` defaults to `root`
* `ENV['LEGACY_DB_DATABASE']` defaults to `opscode_community_site_production`

## Usage

`bundle exec rake chef_legacy:import`
