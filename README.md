## Chef Legacy

Chef Legacy is a rake task that aids in the data migration from the old [Opscode Community Site](community.opscode.com)
to the new [Supermarket](https://github.com/opscode/supermarket) community site. Chef Legacy is intended to be run from
within Supermarket but has been broken out into its own project as it has little use beyond the initial data migration.

## How To Use

1. Clone Chef Legacy into Supermarket within the `lib/tasks` directory.
1. Collect the necessary CSV files from the Opscode Community Site database and place them in `chef-legacy/data`.
   For the most part this is just a matter of dumping the pertinent tables to CSV. Ensure that they are escaped
   with  `"` and not `\`. In order to associate cookbooks to categories you must also ensure that there is a
   `category_name` column in the `cookbooks.csv` that can be derived by joining the cookbooks and categories table.
1. Run `bundle exec rake legacy:import`
