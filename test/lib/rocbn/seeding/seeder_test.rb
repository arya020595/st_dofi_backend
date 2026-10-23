require "test_helper"

module Rocbn
  module Seeding
    # These tests all upsert the same explicit synthetic ids. Their transactions share one MySQL database across
    # process workers, so row locks can deadlock when separate workers run the methods concurrently. A MySQL named
    # lock serializes this class only; the rest of the suite remains parallel.
    class SeederTest < ActiveSupport::TestCase
      include RocbnTestSupport

      LOCK_NAME = "dofi_rocbn_seeder_test".freeze

      setup do
        quoted_lock = ::Rocbn::Company.connection.quote(LOCK_NAME)
        acquired = ::Rocbn::Company.connection.select_value("SELECT GET_LOCK(#{quoted_lock}, 30)")

        assert_equal 1, acquired, "timed out waiting for the ROCBN seeder test lock"
      end

      teardown do
        quoted_lock = ::Rocbn::Company.connection.quote(LOCK_NAME)
        ::Rocbn::Company.connection.select_value("SELECT RELEASE_LOCK(#{quoted_lock})")
      end

      test "seeds every synthetic company, and running it again adds nothing" do
        seeded = Seeder.call(record_class: ::Rocbn::Company)
        count_after_first = synthetic_companies.count
        Seeder.call(record_class: ::Rocbn::Company)

        assert_equal Companies.rows.size, seeded
        assert_equal [count_after_first, count_after_first], [Companies.rows.size, synthetic_companies.count]
      end

      test "a rerun restores a row that was changed, rather than duplicating it" do
        Seeder.call(record_class: ::Rocbn::Company)
        ::Rocbn::Company.where(id: Companies::ID_BASE + 1).update_all(name: "CHANGED") # rubocop:disable Rails/SkipsModelValidations

        Seeder.call(record_class: ::Rocbn::Company)

        assert_equal "AMIIRUL FISH CO.", ::Rocbn::Company.find(Companies::ID_BASE + 1).name
        assert_equal Companies.rows.size, synthetic_companies.count
      end

      test "what it seeds is searchable the way Add Profiling searches" do
        Seeder.call(record_class: ::Rocbn::Company)

        found = ::Rocbn::Company.kept.ransack(company_name_cont: "amiirul").result

        assert_equal ["AMIIRUL FISH CO.", "FISH AMIIRUL SDN. BHD.", "AMIIRUL MARINE SERVICES SDN BHD"].sort,
                     found.map(&:company_name).sort
      end

      private

      def synthetic_companies = ::Rocbn::Company.where(id: Companies::ID_BASE..)
    end
  end
end
