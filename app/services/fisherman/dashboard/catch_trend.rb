module Fisherman
  module Dashboard
    class CatchTrend
      include Dry::Monads[:result]

      DEFAULT_WINDOW_DAYS = 7
      MAX_WINDOW_DAYS = 366
      TIME_ZONE = "Asia/Brunei".freeze

      def self.call(...) = new(...).call

      def initialize(manifest_scope:, start_date:, end_date:)
        @manifest_scope = manifest_scope
        @start_date = start_date
        @end_date = end_date
      end

      def call
        range = date_range
        return Failure(range.errors) if range.invalid?

        Success(CatchTrendQuery.call(manifest_scope:, start_date: range.start_date, end_date: range.end_date,
                                     granularity: range.granularity))
      end

      private

      attr_reader :manifest_scope, :start_date, :end_date

      def date_range
        @date_range ||= DateRange.new(start_date:, end_date:)
      end

      class DateRange
        attr_reader :errors, :start_date, :end_date

        def initialize(start_date:, end_date:)
          @errors = []
          @start_date = parse_date(start_date, "start_date")
          @end_date = parse_date(end_date, "end_date")
          apply_defaults
          validate
        end

        def invalid? = errors.any?

        def granularity
          return :daily if duration_days <= 14
          return :weekly if duration_days <= 90

          :monthly
        end

        private

        def parse_date(value, field)
          return if value.blank?

          Date.iso8601(value)
        rescue ArgumentError
          errors << "#{field} must use YYYY-MM-DD format"
          nil
        end

        def apply_defaults
          return if errors.any?

          today = Time.find_zone!(TIME_ZONE).today
          @end_date ||= today
          @start_date = @end_date - (DEFAULT_WINDOW_DAYS - 1) if @start_date.nil?
        end

        def validate
          return if errors.any?

          errors << "start_date must be on or before end_date" if start_date > end_date
          errors << "date range must not exceed #{MAX_WINDOW_DAYS} days" if duration_days > MAX_WINDOW_DAYS
        end

        def duration_days = (end_date - start_date).to_i + 1
      end
    end
  end
end
