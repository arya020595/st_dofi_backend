module CaptureReports
  class Verify
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(report, actor:)
      return Failure(report) unless report.may_verify?

      report.verify!(actor: actor)
      normalize_manifest_review_state!(report.manifest, actor: actor)
      Notifications::ManifestPublisher.call(
        event: :capture_report_verified,
        manifest: report.manifest,
        capture_report: report
      )
      notify_port_in_approvers(report.manifest)
      Success(report)
    end

    private

    def normalize_manifest_review_state!(manifest, actor:)
      return unless verified_manifest_ready_for_progress?(manifest)
      return complete_small_scale_manifest!(manifest, actor: actor) if complete_small_scale_manifest?(manifest)
      return unless ready_for_port_in_review?(manifest)

      manifest.begin_port_in_review!(actor: actor)
    end

    def verified_manifest_ready_for_progress?(manifest)
      manifest.capture_report_submitted? &&
        manifest.capture_reports.exists? &&
        manifest.capture_reports.all?(&:verified?)
    end

    def complete_small_scale_manifest?(manifest)
      manifest.small_scale? && manifest.may_complete_manifest?
    end

    def complete_small_scale_manifest!(manifest, actor:)
      manifest.complete_manifest!(actor: actor)
    end

    def ready_for_port_in_review?(manifest)
      manifest.port_in_pending? && manifest.may_begin_port_in_review?
    end

    def notify_port_in_approvers(manifest)
      return unless manifest.awaiting_port_in_approval?

      Notifications::ManifestPublisher.call(event: :port_in_review_required, manifest:)
    end
  end
end
