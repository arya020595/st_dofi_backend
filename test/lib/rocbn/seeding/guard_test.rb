require "test_helper"

module Rocbn
  module Seeding
    class GuardTest < ActiveSupport::TestCase
      LOCAL = { host: "rocbn-mysql", port: 3306, username: "rocbn_seed" }.freeze
      OPTED_IN = { "ROCBN_ALLOW_SEED" => "yes" }.freeze

      # Stands in for the seed writer: only what check_data! asks of it.
      FakeRecord = Struct.new(:real_rows, :exists) do
        def table_exists? = exists
        def where(*) = Data.define(:count).new(real_rows)
      end

      test "a local target with the opt-in is approved" do
        assert_nothing_raised { guard(LOCAL).check_target! }
      end

      test "refuses without the explicit opt-in, and any value but yes is not one" do
        [{}, { "ROCBN_ALLOW_SEED" => "true" }, { "ROCBN_ALLOW_SEED" => "1" }].each do |env|
          error = assert_raises(Guard::Blocked) { guard(LOCAL, env: env).check_target! }

          assert_match(/ROCBN_ALLOW_SEED=yes/, error.message)
        end
      end

      test "refuses the production registry by host and by port, even with the opt-in" do
        [LOCAL.merge(host: "10.252.8.23", port: 3306), LOCAL.merge(port: 9139)].each do |config|
          error = assert_raises(Guard::Blocked) { guard(config).check_target! }

          assert_match(/production ROCBN server/, error.message)
        end
      end

      test "refuses a host that is not a local MySQL" do
        ["db.example.com", "10.0.0.5", "rocbn-mysql.example.com", ""].each do |host|
          assert_raises(Guard::Blocked) { guard(LOCAL.merge(host: host)).check_target! }
        end
      end

      test "approves every local host and nothing it has not been told about" do
        assert(%w[rocbn-mysql localhost 127.0.0.1 ::1 host.docker.internal].all? { |host| Guard.local_host?(host) })
        assert_not Guard.local_host?(nil)
      end

      test "refuses when the seed credentials are not set" do
        error = assert_raises(Guard::Blocked) { guard({ port: 3306 }).check_target! }

        assert_match(/ROCBN_SEED_DB_HOST and ROCBN_SEED_DB_USERNAME/, error.message)
      end

      test "reports every problem at once" do
        error = assert_raises(Guard::Blocked) { guard(LOCAL.merge(host: "10.252.8.23"), env: {}).check_target! }

        assert_equal 3, error.message.lines.grep(/\A  - /).size
      end

      test "refuses a database that already holds rows below the synthetic block, as a tunnel to production would" do
        error = assert_raises(Guard::Blocked) { guard(LOCAL).check_data!(FakeRecord.new(185_282, true)) }

        assert_match(/185282 row\(s\) below id #{Guard::SYNTHETIC_ID_FLOOR}/, error.message)
      end

      test "approves an empty database, a synthetic one, and a table that does not exist yet" do
        assert_nothing_raised do
          guard(LOCAL).check_data!(FakeRecord.new(0, true))
          guard(LOCAL).check_data!(FakeRecord.new(0, false))
        end
      end

      private

      def guard(config, env: OPTED_IN) = Guard.new(config: config, env: env)
    end
  end
end
