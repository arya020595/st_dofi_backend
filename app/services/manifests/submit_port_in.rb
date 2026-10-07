module Manifests
  class SubmitPortIn
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    # The lock matters: Port-In submission and a DoFi Officer's verification are separate requests, and whichever
    # runs last must see the other's committed state to move the manifest on.
    def call(manifest, actor:)
      result = manifest.with_lock do
        next rejected(manifest) unless manifest.may_submit_port_in?

        reset_capture_reports_for_port_in!(manifest)
        manifest.submit_port_in!(actor: actor)
        manifest.complete_capture_report!(actor: actor)
        move_manifest_on(manifest, actor)
        Success(manifest)
      end

      notify_reviewers(manifest) if result.success?
      result
    end

    private

    # Both legs are now known: the manifest completes, or a commercial Port-In goes to the Jetty Manager.
    def move_manifest_on(manifest, actor)
      if manifest.may_complete_manifest?
        manifest.complete_manifest!(actor: actor)
        RecordFishingGearUsage.call(manifest)
      elsif manifest.may_begin_port_in_review?
        manifest.begin_port_in_review!(actor: actor)
      end
    end

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
      manifest.sync_capture_report_amendment_snapshot!
    end

    def notify_capture_verifiers(manifest)
      Notifications::ManifestPublisher.call(event: :capture_report_review_required, manifest:)
    end

    def notify_port_in_approvers(manifest)
      Notifications::ManifestPublisher.call(event: :port_in_review_required, manifest:)
    end

    # Port-In can't be submitted yet: either the Capture Report step is missing, or the state doesn't allow it.
    def rejected(manifest)
      unless manifest.capture_report_ready?
        manifest.errors.add(:base, "Capture report must be submitted or skipped before requesting port-in")
      end
      Failure(manifest)
    end
  end
end
