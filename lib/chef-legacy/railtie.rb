require 'rails'

module ChefLegacy
  class Railtie < Rails::Railtie
    railtie_name :chef_data_import

    rake_tasks do
      load "tasks/supermarket/import.rake"
    end
  end
end