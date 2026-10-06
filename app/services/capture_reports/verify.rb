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
      notify_port_in_approvers(report.manifest)
      Success(report)
    end

    private

    def notify_port_in_approvers(manifest)
      return unless manifest.awaiting_port_in_approval?

      Notifications::ManifestPublisher.call(event: :port_in_review_required, manifest:)
    end
  end
end
