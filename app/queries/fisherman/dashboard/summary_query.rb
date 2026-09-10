module Fisherman
  module Dashboard
    class SummaryQuery < BaseQuery
      def self.call(...) = new(...).call

      def call
        {
          total_catch_kg: totals[0],
          overall_total: totals[1],
          total_trips: total_trips
        }
      end

      private

      def total_trips = verified_capture_reports.distinct.count(:manifest_id)

      def totals
        @totals ||= fish_capture_details.pick(
          Arel.sql("COALESCE(SUM(fish_capture_details.amount_captured_kg), 0)"),
          Arel.sql("COALESCE(SUM(fish_capture_details.overall_total), 0)")
        )
      end
    end
  end
end
