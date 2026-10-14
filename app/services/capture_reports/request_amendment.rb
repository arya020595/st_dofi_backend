module CaptureReports
  class RequestAmendment
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(report, actor:, remarks:)
      manifest = report.manifest
      manifest.with_lock do
        report.reload
        next Failure(report) unless report.may_request_amendment?

        report.request_amendment!(actor: actor, remarks: remarks)
        stamp_review(report, manifest, actor, remarks)
        notify_fisherman(report, manifest)
        Success(report)
      end
    end

    private

    def stamp_review(report, manifest, actor, remarks)
      report.update!(reviewed_by_id: actor&.id, reviewed_at: Time.current, capture_report_remarks: remarks)
      manifest.sync_capture_report_amendment_snapshot!
    end

    def notify_fisherman(report, manifest)
      Notifications::ManifestPublisher.enqueue(
        event: :capture_report_amendment_required,
        manifest: manifest,
        capture_report: report
      )
    end
  end
end
