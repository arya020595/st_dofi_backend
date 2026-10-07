module CaptureReports
  class Verify
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(report, actor:)
      return Failure(report) unless report.may_verify?

      report.verify!(actor: actor)
      Notifications::ManifestPublisher.call(
        event: :capture_report_verified,
        manifest: report.manifest,
        capture_report: report
      )
      Success(report)
    end
  end
end
