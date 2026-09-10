module Fisherman
  module Dashboard
    class BaseQuery
      DEFAULT_WINDOW_DAYS = 30

      def initialize(manifest_scope:, start_date:, end_date:)
        @manifest_scope = manifest_scope
        @start_time = resolve_start_time(start_date)
        @end_time = resolve_end_time(end_date)
      end

      private

      attr_reader :manifest_scope, :start_time, :end_time

      def verified_capture_reports
        CaptureReport.joins(:manifest)
                     .merge(manifest_scope)
                     .where(capture_report_status: "verified", reviewed_at: start_time..end_time)
      end

      def fish_capture_details
        FishCaptureDetail.joins(:capture_report)
                         .merge(verified_capture_reports)
      end

      def fishing_gear_details
        FishingGearDetail.joins(:capture_report)
                         .merge(verified_capture_reports)
      end

      def resolve_start_time(value)
        return DEFAULT_WINDOW_DAYS.days.ago.beginning_of_day if value.blank?

        Time.zone.parse(value.to_s)&.beginning_of_day || DEFAULT_WINDOW_DAYS.days.ago.beginning_of_day
      end

      def resolve_end_time(value)
        return Time.current.end_of_day if value.blank?

        Time.zone.parse(value.to_s)&.end_of_day || Time.current.end_of_day
      end
    end
  end
end
