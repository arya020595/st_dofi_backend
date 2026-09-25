module Fisherman
  module Dashboard
    class CatchTrendQuery
      TIME_ZONE = "Asia/Brunei".freeze

      def self.call(...) = new(...).call

      def initialize(manifest_scope:, start_date:, end_date:, granularity:)
        @manifest_scope = manifest_scope
        @start_date = start_date
        @end_date = end_date
        @granularity = granularity
      end

      def call
        { granularity: granularity.to_s, buckets: bucket_dates.map { |date| bucket_payload(date) } }
      end

      private

      attr_reader :manifest_scope, :start_date, :end_date, :granularity

      def bucket_payload(date)
        bucket_start, bucket_end = bounded_bucket(date)
        {
          start_date: bucket_start.iso8601,
          end_date: bucket_end.iso8601,
          total_catch_kg: totals_by_bucket.fetch(date, 0)
        }
      end

      def totals_by_bucket
        @totals_by_bucket ||= fish_capture_details
                              .group(bucket_expression)
                              .pluck(bucket_expression, total_catch_expression)
                              .to_h
      end

      def fish_capture_details
        FishCaptureDetail.joins(capture_report: :manifest)
                         .merge(manifest_scope)
                         .where(capture_reports: { capture_report_status: "verified" })
                         .where(capture_reports: { reviewed_at: start_time...end_time })
      end

      def bucket_dates
        case granularity
        when :daily then (start_date..end_date).to_a
        when :weekly then calendar_weeks
        when :monthly then calendar_months
        end
      end

      def calendar_weeks
        first = start_date.beginning_of_week
        last = end_date.beginning_of_week
        first.step(last, 7).to_a
      end

      def calendar_months
        first = start_date.beginning_of_month
        last = end_date.beginning_of_month
        months = []
        current = first
        while current <= last
          months << current
          current = current.next_month
        end
        months
      end

      def bounded_bucket(date)
        bucket_start, bucket_end = case granularity
                                   when :daily then [date, date]
                                   when :weekly then [date, date.end_of_week]
                                   when :monthly then [date, date.end_of_month]
                                   end
        [[bucket_start, start_date].max, [bucket_end, end_date].min]
      end

      def bucket_expression
        @bucket_expression ||= Arel.sql(
          case granularity
          when :daily
            "DATE(capture_reports.reviewed_at AT TIME ZONE '#{TIME_ZONE}')"
          when :weekly
            "DATE_TRUNC('week', capture_reports.reviewed_at AT TIME ZONE '#{TIME_ZONE}')::date"
          when :monthly
            "DATE_TRUNC('month', capture_reports.reviewed_at AT TIME ZONE '#{TIME_ZONE}')::date"
          end
        )
      end

      def total_catch_expression
        Arel.sql("COALESCE(SUM(fish_capture_details.amount_captured_kg), 0)")
      end

      def start_time = start_date.in_time_zone(TIME_ZONE).beginning_of_day
      def end_time = (end_date + 1).in_time_zone(TIME_ZONE).beginning_of_day
    end
  end
end
