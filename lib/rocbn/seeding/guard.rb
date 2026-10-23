module Rocbn
  module Seeding
    # The hard stop in front of everything that writes to a ROCBN database (rocbn:seed and the test support). It
    # decides on the target itself, never on Rails.env: staging runs as RAILS_ENV=production. Three independent
    # checks, all required:
    #   1. ROCBN_ALLOW_SEED=yes was set for this run (it never belongs in a production or staging .env file);
    #   2. the host is a local or Docker-internal MySQL, and not the known production registry endpoint;
    #   3. the target table is empty or holds only synthetic rows. A host check cannot see this one: an SSH tunnel
    #      to the production server reaches it as "localhost".
    class Guard
      class Blocked < StandardError; end

      ALLOWED_HOSTS = %w[rocbn-mysql localhost 127.0.0.1 ::1 host.docker.internal].freeze
      PRODUCTION_ENDPOINT = { host: "10.252.8.23", port: 9139 }.freeze
      # Synthetic rows live at and above this id; the real registry's ids are all far below it.
      SYNTHETIC_ID_FLOOR = 9_000_000

      def self.local_host?(host) = ALLOWED_HOSTS.include?(host.to_s.downcase)

      def initialize(config:, env: ENV)
        @config = config
        @env = env
      end

      # No I/O: safe to run before anything connects.
      def check_target!
        raise_blocked(target_problems)
      end

      # Needs the connection, so it only runs after check_target! passed.
      def check_data!(record_class)
        return unless record_class.table_exists?

        real_rows = record_class.where(id: ...SYNTHETIC_ID_FLOOR).count
        return if real_rows.zero?

        raise_blocked(["the table holds #{real_rows} row(s) below id #{SYNTHETIC_ID_FLOOR}: not a synthetic database"])
      end

      private

      def target_problems
        [
          ("ROCBN_ALLOW_SEED=yes is not set for this run" unless @env["ROCBN_ALLOW_SEED"] == "yes"),
          ("ROCBN_SEED_DB_HOST and ROCBN_SEED_DB_USERNAME must both be set" unless credentials_given?),
          ("host #{host.inspect} is not a local MySQL (allowed: #{ALLOWED_HOSTS.join(', ')})" unless allowed_host?),
          ("#{host}:#{port} is the production ROCBN server" if production_endpoint?)
        ].compact
      end

      def credentials_given? = host.present? && @config[:username].present?
      def allowed_host? = self.class.local_host?(host)
      def host = @config[:host].to_s
      def port = @config[:port].to_i

      def production_endpoint?
        host == PRODUCTION_ENDPOINT[:host] || port == PRODUCTION_ENDPOINT[:port]
      end

      def raise_blocked(problems)
        return if problems.empty?

        lines = problems.map { |problem| "  - #{problem}" }
        raise Blocked, "Refusing to write to the ROCBN database:\n#{lines.join("\n")}"
      end
    end
  end
end
