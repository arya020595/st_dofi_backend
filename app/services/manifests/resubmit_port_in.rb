module Manifests
  class ResubmitPortIn
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:)
      manifest.with_lock do
        if capture_report_amendment_resubmittable?(manifest)
          resubmit_capture_reports(manifest, actor: actor)
        else
          resubmit_port_in(manifest, actor: actor)
        end
      end
    end

    private

    def resubmit_port_in(manifest, actor:)
      return Failure(manifest) unless manifest.may_resubmit_port_in?

      manifest.resubmit_port_in!(actor: actor)
      manifest.update!(port_in_amendment_remarks: nil)
      # The reports may have been verified while the Port-In was with the fisherman.
      manifest.begin_port_in_review!(actor: actor) if manifest.may_begin_port_in_review?
      Notifications::ManifestPublisher.enqueue(event: :port_in_resubmitted, manifest:)
      Success(manifest)
    end

    def capture_report_amendment_resubmittable?(manifest)
      manifest.capture_report_submitted? &&
        manifest.port_in_pending? &&
        manifest.capture_reports.exists?(capture_report_status: "needs_amendment")
    end

    def resubmit_capture_reports(manifest, actor:)
      manifest.capture_reports.where(capture_report_status: "needs_amendment").find_each do |report|
        CaptureReports::Resubmit.call(report, actor: actor).value!
      end

      Success(manifest)
    end
  end
end
