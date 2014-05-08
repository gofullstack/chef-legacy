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

To connect to a different database, set the `COMMUNITY_SITE_DATABASE_URL` environment variable. For example, the default URL is `mysql://root:@127.0.0.1:3306/opscode_community_site_production`.

## Usage

`bundle exec rake supermarket:migrate -j N`

Set `N` to the maximum number of tasks to run in parallel. Factors to consider when choosing N include the number of cores available, as well as the size of ActiveRecord's connection pool.

## Implementation Overview

The `migrate` task is split into three parts: `import`, `cull`, and `amend`. `import` determines which records from the Opscode Community Site have yet to be imported and imports them. `cull` determines which imported records no longer exist in the Opscode Community Site and deletes them. `amend` combs through imported cookbooks and makes sure that any updates on the existing community site make their way to Supermarket.

Take the User migration for example, which is configured as follows:

```ruby
module Supermarket
  module Import
    class User
      class << self
        extend Configuration

        list_ids_with %{
          SELECT users.id FROM users
          INNER JOIN email_addresses ON email_addresses.user_id = users.id
          WHERE users.deleted_at IS NULL
          AND email_addresses.address != ''
        }

        migrate :UserRecord => :User
      end
    end
  end
end
```

We first specify a SQL query which will list the IDs of Opscode Community Site User records which ought to exist in Supermarket. We then specify that the migration path is from `UserRecord` (an object wrapping an Opscode Community Site user record) to `User` (a Supermarket model which is set up to store the Opscode Community Site user record's ID in a field named `legacy_id`). Each class in the `Import` namespace is `Enumerable` over unimported records at the start of its migration path. More concretely, can import the first unimported Community Site user as follows:

```ruby
require 'supermarket/import'

user_record = Supermarket::Import::User.first

if user_record
  import = Supermarket::Import::User.new(user_record)
  import.call
end
```

The entire import process is nothing more than iterating over a class in the `Import` namespace, instantiating an instance of that class, and sending it `call`. It's worth noting that each import happens inside of an ActiveRecord transaction on the off chance there's bad data in the Community Site database, and we fail to massage it correctly.

Culling works in a similar way, but in reverse.

Amending is an operation that only makes sense for User data and for Cookbook data. Given that the definitive source for User data is, or will be, oc-id, `chef-legacy` only amends Cookbook data. We only amend a cookbook if the Community Site `updated_at` timestamp is more recent than Supermarket `updated_at` timestamp. There's a possibility that we'll miss updates due to clock discrepancies, but cookbook data does not change very often so this will hopefully not be a problem.
