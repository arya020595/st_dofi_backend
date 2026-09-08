module CaptureReports
  class Resubmit
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(report, actor:)
      return Failure(report) unless report.may_resubmit?

      report.resubmit!(actor: actor)
      Notifications::ManifestPublisher.call(
        event: :capture_report_resubmitted,
        manifest: report.manifest,
        capture_report: report
      )
      Success(report)
    end
  end
end
