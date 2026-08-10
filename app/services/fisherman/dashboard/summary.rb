module Fisherman
  module Dashboard
    class Summary < BaseQuery
      def self.call(...) = new(...).call

      def call
        {
          total_catch_kg: total_catch_kg,
          estimated_revenue: estimated_revenue,
          total_trips:,
          catch_per_unit_effort: catch_per_unit_effort(total_catch_kg, total_trips)
        }
      end

      private

      def total_catch_kg = totals[0].to_f.round(3)
      def estimated_revenue = totals[1].to_f.round(2)
      def total_trips = verified_capture_reports.distinct.count(:manifest_id)

      def catch_per_unit_effort(total_catch_kg, total_trips)
        return 0.0 if total_trips.zero?

        (total_catch_kg / total_trips).round(2)
      end

      def totals
        @totals ||= fish_capture_details.pick(
          Arel.sql("COALESCE(SUM(fish_capture_details.amount_captured_kg), 0)"),
          Arel.sql("COALESCE(SUM(fish_capture_details.overall_total), 0)")
        )
      end
    end
  end
end
