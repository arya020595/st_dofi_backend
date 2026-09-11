module Fisherman
  module Dashboard
    class Summary
      def self.call(...) = new(...).call

      def initialize(**query_attributes)
        @query_attributes = query_attributes
      end

      def call
        data = SummaryQuery.call(**@query_attributes)

        {
          total_catch_kg: data[:total_catch_kg],
          estimated_revenue: data[:overall_total],
          total_trips: data[:total_trips],
          catch_per_unit_effort: catch_per_unit_effort(data[:total_catch_kg], data[:total_trips])
        }
      end

      private

      def catch_per_unit_effort(total_catch_kg, total_trips)
        return 0.0 if total_trips.zero?

        total_catch_kg.to_f / total_trips
      end
    end
  end
end
