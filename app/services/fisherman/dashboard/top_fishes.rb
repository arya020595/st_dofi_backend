module Fisherman
  module Dashboard
    class TopFishes < BaseQuery
      LIMIT = 5

      def self.call(...) = new(...).call

      def call
        rows.map { |row| serialize(row) }
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

      def serialize(row)
        dictionary_id, local_name, scientific_name, total_catch_kg = row

        {
          dictionary_id: dictionary_id,
          local_name: local_name,
          scientific_name: scientific_name,
          total_catch_kg: total_catch_kg.to_f.round(3)
        }
      end
    end
  end
end
