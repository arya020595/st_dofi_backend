module CaptureReports
  class RequestAmendment
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(report, actor:, remarks:)
      result = ActiveRecord::Base.transaction do
        next Failure(report) unless report.may_request_amendment?

        report.request_amendment!(actor: actor, remarks: remarks)
        report.update!(reviewed_by_id: actor&.id, reviewed_at: Time.current, capture_report_remarks: remarks)
        report.manifest.sync_capture_report_amendment_snapshot!
        Success(report)
      end

      notify_fisherman(report) if result.success?
      result
    end

    private

    def notify_fisherman(report)
      Notifications::ManifestPublisher.call(
        event: :capture_report_amendment_required,
        manifest: report.manifest,
        capture_report: report
      )
    end
  end
end
