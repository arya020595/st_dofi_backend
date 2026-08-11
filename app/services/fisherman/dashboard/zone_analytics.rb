module Fisherman
  module Dashboard
    class ZoneAnalytics < BaseQuery
      def self.call(...) = new(...).call

      def call
        rows.map { |row| serialize(row) }
      end

      private

      def rows
        fish_capture_details.group("capture_reports.zone_id", "capture_reports.zone_area")
                            .order(Arel.sql("SUM(fish_capture_details.amount_captured_kg) DESC"))
                            .pluck(
                              "capture_reports.zone_id",
                              "capture_reports.zone_area",
                              Arel.sql("COALESCE(SUM(fish_capture_details.amount_captured_kg), 0)")
                            )
      end

      def serialize(row)
        zone_id, zone_area, total_catch_kg = row

        {
          zone_id: zone_id,
          zone_area: zone_area,
          total_catch_kg: total_catch_kg.to_f.round(3)
        }
      end
    end
  end
end
