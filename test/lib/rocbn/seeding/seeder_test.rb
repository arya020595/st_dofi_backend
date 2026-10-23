require "test_helper"

module Rocbn
  module Seeding
    # The one test that writes explicit ids, so parallel workers cannot collide on them: it runs in its own
    # transaction on the shared test database, and nothing else inserts ids in the synthetic block.
    class SeederTest < ActiveSupport::TestCase
      include RocbnTestSupport

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
