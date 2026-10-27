require "test_helper"

module Rocbn
  module Seeding
    # Runner against a stand-in writer that only records what it was asked to do: what matters is what is NOT done
    # when the Guard refuses.
    class RunnerTest < ActiveSupport::TestCase
      LOCAL_ENV = { "ROCBN_ALLOW_SEED" => "yes", "ROCBN_SEED_DB_HOST" => "rocbn-mysql",
                    "ROCBN_SEED_DB_USERNAME" => "rocbn_seed", "ROCBN_SEED_DB_PASSWORD" => "secret" }.freeze

      class RecordingWriter
        attr_reader :calls

        def initialize(real_rows: 0)
          @real_rows = real_rows
          @calls = []
        end

        def connect!(_config) = @calls << :connect
        def table_exists? = true
        def where(*) = Data.define(:count).new(@real_rows)
        def upsert_all(*, **) = @calls << :write
        def lease_connection = Struct.new(:calls) { def execute(_sql) = calls << :schema }.new(@calls)
      end

      test "a refused target is never connected to or written to" do
        writer = RecordingWriter.new

        assert_raises(Guard::Blocked) { seed_with(LOCAL_ENV.except("ROCBN_ALLOW_SEED"), writer) }
        assert_empty writer.calls
      end

      test "a database with real rows is connected to for the check, and never written to" do
        writer = RecordingWriter.new(real_rows: 185_282)

        assert_raises(Guard::Blocked) { seed_with(LOCAL_ENV, writer) }
        assert_equal [:connect], writer.calls
      end

      test "an approved target gets its schema ensured, then the companies" do
        writer = RecordingWriter.new
        out = StringIO.new

        Runner.call(env: LOCAL_ENV, out: out, record_class: writer)

        assert_equal %i[connect schema write], writer.calls
        assert_match(%r{Seeded #{Companies.rows.size} synthetic companies into rocbn-mysql:3306/tdd_db}, out.string)
      end

      test "it never reads the runtime ROCBN_DB_* variables" do
        env = LOCAL_ENV.except("ROCBN_SEED_DB_HOST").merge("ROCBN_DB_HOST" => "rocbn-mysql",
                                                           "ROCBN_DB_USERNAME" => "rocbn_reader")

        assert_raises(Guard::Blocked) { seed_with(env, RecordingWriter.new) }
      end

      private

      def seed_with(env, writer) = Runner.call(env: env, out: StringIO.new, record_class: writer)
    end
  end
end
