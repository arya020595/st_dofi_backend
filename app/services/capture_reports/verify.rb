module CaptureReports
  class Verify
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    # The lock is on the manifest: a DoFi Officer's verification and the Jetty Manager's approval are separate
    # requests, and whichever runs last must see the other's committed state to move the manifest on.
    def call(report, actor:)
      manifest = report.manifest
      result = manifest.with_lock do
        next Failure(report) unless report.may_verify?

        report.verify!(actor: actor)
        stamp_review(report, manifest, actor)
        move_manifest_on(manifest, actor)
        Success(report)
      end

      notify_fisherman(report) if result.success?
      result
    end

    private

    def stamp_review(report, manifest, actor)
      report.update!(reviewed_by_id: actor&.id, reviewed_at: Time.current)
      manifest.sync_capture_report_amendment_snapshot!
    end

    # Both legs are now known: the manifest completes, or a commercial Port-In goes to the Jetty Manager.
    def move_manifest_on(manifest, actor)
      if manifest.may_complete_manifest?
        manifest.complete_manifest!(actor: actor)
        Manifests::RecordFishingGearUsage.call(manifest)
      elsif manifest.may_begin_port_in_review?
        manifest.begin_port_in_review!(actor: actor)
      end
    end

    def notify_fisherman(report)
      Notifications::ManifestPublisher.call(
        event: :capture_report_verified,
        manifest: report.manifest,
        capture_report: report
      )
    end
  end
end
