module CaptureReports
  class Resubmit
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(report, actor:)
      manifest = report.manifest
      manifest.with_lock do
        report.reload
        next Failure(report) unless report.may_resubmit?

        report.resubmit!(actor: actor)
        clear_review(report, manifest)
        notify_verifiers(report, manifest)
        Success(report)
      end
    end

    private

    def clear_review(report, manifest)
      report.update!(reviewed_by_id: nil, reviewed_at: nil, capture_report_remarks: nil)
      manifest.sync_capture_report_amendment_snapshot!
    end

    def notify_verifiers(report, manifest)
      Notifications::ManifestPublisher.enqueue(
        event: :capture_report_resubmitted,
        manifest: manifest,
        capture_report: report
      )
    end
  end
end
