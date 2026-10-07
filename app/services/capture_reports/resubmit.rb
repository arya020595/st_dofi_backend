module CaptureReports
  class Resubmit
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(report, actor:)
      result = ActiveRecord::Base.transaction do
        next Failure(report) unless report.may_resubmit?

        report.resubmit!(actor: actor)
        report.update!(reviewed_by_id: nil, reviewed_at: nil, capture_report_remarks: nil)
        report.manifest.sync_capture_report_amendment_snapshot!
        Success(report)
      end

      notify_verifiers(report) if result.success?
      result
    end

    private

    def notify_verifiers(report)
      Notifications::ManifestPublisher.call(
        event: :capture_report_resubmitted,
        manifest: report.manifest,
        capture_report: report
      )
    end
  end
end
