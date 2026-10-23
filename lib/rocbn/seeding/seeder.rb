module Rocbn
  module Seeding
    # Upserts the synthetic companies by primary key, so running it again updates the same rows and never adds
    # duplicates. The record class is injected: Record (the seed account) in rocbn:seed, the test model in tests.
    class Seeder
      def self.call(...) = new(...).call

      def initialize(record_class:, rows: Companies.rows)
        @record_class = record_class
        @rows = rows
      end

      def call
        # MySQL upserts through ON DUPLICATE KEY (the primary key is the only unique key), hence no unique_by.
        @record_class.upsert_all(@rows, record_timestamps: false) # rubocop:disable Rails/SkipsModelValidations
        @rows.size
      end
    end
  end
end
