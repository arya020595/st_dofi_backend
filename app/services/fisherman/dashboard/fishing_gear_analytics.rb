module Fisherman
  module Dashboard
    class FishingGearAnalytics < BaseQuery
      def self.call(...) = new(...).call

      def call
        rows.map { |row| serialize(row) }
      end

      private

      def rows
        fishing_gear_details.left_joins(companies_fishing_gear: :fishing_gear)
                            .joins(:fish_capture_details)
                            .group(*group_columns)
                            .order(Arel.sql("SUM(fish_capture_details.amount_captured_kg) DESC"))
                            .pluck(*pluck_columns)
      end

      def group_columns
        [
          "fishing_gear_details.companies_fishing_gear_id",
          "companies_fishing_gears.fishing_gear_id",
          "fishing_gear_details.name",
          "fishing_gear_details.gear_type"
        ]
      end

      def pluck_columns
        [
          "fishing_gear_details.companies_fishing_gear_id",
          "companies_fishing_gears.fishing_gear_id",
          "fishing_gear_details.name",
          "fishing_gear_details.gear_type",
          Arel.sql("COALESCE(SUM(fish_capture_details.amount_captured_kg), 0)")
        ]
      end

      def serialize(row)
        companies_fishing_gear_id, fishing_gear_id, name, gear_type, total_catch_kg = row

        {
          companies_fishing_gear_id: companies_fishing_gear_id,
          fishing_gear_id: fishing_gear_id,
          name: name,
          gear_type: gear_type,
          total_catch_kg: total_catch_kg.to_f.round(3)
        }
      end
    end
  end
end
