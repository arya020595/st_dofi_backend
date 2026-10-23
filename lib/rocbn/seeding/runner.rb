module Rocbn
  module Seeding
    # What `bin/rails rocbn:seed` runs: build the seed connection from ROCBN_SEED_DB_*, let Guard approve the target,
    # make sure the table exists, then upsert the synthetic companies. It reads only the seed variables, never the
    # ROCBN_DB_* runtime ones, so a production runtime account can never be reached from here.
    class Runner
      def self.call(...) = new(...).call

      def initialize(env: ENV, out: $stdout, record_class: Record)
        @env = env
        @out = out
        @record_class = record_class
      end

      def call
        config = connection_config
        guard = Guard.new(config: config, env: @env)
        guard.check_target!
        @record_class.connect!(config)
        guard.check_data!(@record_class)
        Schema.load!(@record_class)
        @out.puts "Seeded #{Seeder.call(record_class: @record_class)} synthetic companies into " \
                  "#{config[:host]}:#{config[:port]}/#{config[:database]}"
      end

      private

      def connection_config
        {
          adapter: "trilogy", host: @env["ROCBN_SEED_DB_HOST"], port: @env.fetch("ROCBN_SEED_DB_PORT", 3306).to_i,
          database: @env.fetch("ROCBN_SEED_DB_NAME", "tdd_db"), username: @env["ROCBN_SEED_DB_USERNAME"],
          password: @env["ROCBN_SEED_DB_PASSWORD"], encoding: "utf8mb4", collation: "utf8mb4_unicode_ci",
          ssl_mode: "preferred", connect_timeout: 3, read_timeout: 15, write_timeout: 15
        }
      end
    end
  end
end
