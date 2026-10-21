module CaptureReports
  class NumberGenerator
    def self.call(timestamp: Time.current) = new(timestamp:).call

    def initialize(timestamp:)
      @timestamp = timestamp
    end

    def call
      SequenceGenerator.next_value(key: :capture_report_number, prefix: "CAPTURE-#{number_date}-")
    end

    private

    def number_date = @timestamp.in_time_zone("Asia/Brunei").strftime("%Y%m%d")
  end
end
