module CaptureReports
  # Fires one Capture Report event (verify / request_amendment / resubmit), stamps the review, keeps the
  # manifest's amendment snapshot current and lets the manifest advance. Notifications are the caller's job.
  #
  #   Transition.call(report, :verify, actor: officer)  # => Success(report) | Failure(report)
  class Transition
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(report, event, actor: nil, remarks: nil)
      return Failure(report) unless report.public_send(:"may_#{event}?")

      ActiveRecord::Base.transaction do
        report.public_send(:"#{event}!", actor: actor, remarks: remarks)
        stamp_review(report, event, actor: actor, remarks: remarks)
        Manifests::AmendmentSnapshot.sync_capture_report(report.manifest)
        Manifests::Advance.call(report.manifest, actor: actor)
      end
      Success(report)
    end

    private

    def stamp_review(report, event, actor:, remarks:)
      case event
      when :verify
        report.update!(reviewed_by_id: actor&.id, reviewed_at: Time.current)
      when :request_amendment
        report.update!(reviewed_by_id: actor&.id, reviewed_at: Time.current, capture_report_remarks: remarks)
      when :resubmit
        report.update!(reviewed_by_id: nil, reviewed_at: nil, capture_report_remarks: nil)
      end
    end
  end
end
