module Rocbn
  module Seeding
    # The writer behind rocbn:seed: the registry table bound to the ROCBN_SEED_DB_* account, never to the read-only
    # runtime one. Not connected until Runner hands it a config that passed Guard#check_target!.
    class Record < ActiveRecord::Base # rubocop:disable Rails/ApplicationRecord
      self.table_name = "sync_rocbn_hotel"

      def self.connect!(config)
        establish_connection(ActiveRecord::DatabaseConfigurations::HashConfig.new("seed", "rocbn_seed", config))
      end
    end
  end
end
