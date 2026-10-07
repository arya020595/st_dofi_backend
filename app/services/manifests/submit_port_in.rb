module Manifests
  class SubmitPortIn
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:)
      return not_ready(manifest) unless manifest.capture_report_ready?
      return Failure(manifest) unless manifest.may_submit_port_in?

      ActiveRecord::Base.transaction do
        reset_capture_reports_for_port_in!(manifest)
        Transition.call(manifest, :submit_port_in, actor: actor).value!
      end

      notify_reviewers(manifest)
      Success(manifest)
    end

    private

    # Reports to verify go to DoFi Officers. A commercial Port-In goes to the Jetty Manager right away: the two
    # reviews run in parallel, so approval never waits on verification. A skipped small-scale manifest completes
    # with nobody to notify.
    def notify_reviewers(manifest)
      notify_capture_verifiers(manifest) if manifest.capture_report_submitted?
      notify_port_in_approvers(manifest) if manifest.port_in_pending?
    end

    def reset_capture_reports_for_port_in!(manifest)
      manifest.capture_reports.find_each do |report|
        report.update!(
          capture_report_status: "pending_verification",
          capture_report_remarks: nil,
          reviewed_by_id: nil,
          reviewed_at: nil
        )
      end
    end

    def notify_capture_verifiers(manifest)
      Notifications::ManifestPublisher.call(event: :capture_report_review_required, manifest:)
    end

    def notify_port_in_approvers(manifest)
      Notifications::ManifestPublisher.call(event: :port_in_review_required, manifest:)
    end

    def not_ready(manifest)
      manifest.errors.add(:base, "Capture report must be submitted or skipped before requesting port-in")
      Failure(manifest)
    end
  end
end
