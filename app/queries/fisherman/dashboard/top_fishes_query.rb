module Fisherman
  module Dashboard
    class TopFishesQuery < BaseQuery
      LIMIT = 5

      def self.call(...) = new(...).call

      def call
        rows.map { |row| to_hash(row) }
      end

      private

      def rows
        fish_capture_details.group(:dictionary_id, :local_name, :scientific_name)
                            .order(Arel.sql("SUM(fish_capture_details.amount_captured_kg) DESC"))
                            .limit(LIMIT)
                            .pluck(
                              :dictionary_id,
                              :local_name,
                              :scientific_name,
                              Arel.sql("COALESCE(SUM(fish_capture_details.amount_captured_kg), 0)")
                            )
      end

      def to_hash(row)
        dictionary_id, local_name, scientific_name, total_catch_kg = row

        {
          dictionary_id: dictionary_id,
          local_name: local_name,
          scientific_name: scientific_name,
          total_catch_kg: total_catch_kg
        }
      end
    end
  end
end
