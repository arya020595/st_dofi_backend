module CaptureReports
  class RequestAmendment
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(report, actor:, remarks:)
      return Failure(report) unless report.may_request_amendment?

      report.request_amendment!(actor: actor, remarks: remarks)
      Notifications::ManifestPublisher.call(
        event: :capture_report_amendment_required,
        manifest: report.manifest,
        capture_report: report
      )
      Success(report)
    end
  end
end
