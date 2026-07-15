module CaptureReports
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(report, attributes)
      return Failure(report) unless report.editable?
      return Success(report) if report.update(attributes)

      Failure(report)
    end
  end
end
