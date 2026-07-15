module CaptureReports
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, attributes)
      report = manifest.capture_reports.new(attributes)
      return Failure(report) unless report.save

      Success(report)
    end
  end
end
