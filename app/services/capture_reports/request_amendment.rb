module CaptureReports
  class RequestAmendment
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(report, actor:, remarks:)
      return Failure(report) unless report.may_request_amendment?

      report.request_amendment!(actor: actor, remarks: remarks)
      Success(report)
    end
  end
end
