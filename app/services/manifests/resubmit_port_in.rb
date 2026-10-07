module Manifests
  class ResubmitPortIn
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:)
      return resubmit_capture_reports(manifest, actor: actor) if capture_report_amendment_resubmittable?(manifest)

      resubmit_port_in(manifest, actor: actor)
    end

    private

    def resubmit_port_in(manifest, actor:)
      result = manifest.with_lock do
        next Failure(manifest) unless manifest.may_resubmit_port_in?

        manifest.resubmit_port_in!(actor: actor)
        manifest.update!(port_in_amendment_remarks: nil)
        # The reports may have been verified while the Port-In was with the fisherman.
        manifest.begin_port_in_review!(actor: actor) if manifest.may_begin_port_in_review?
        Success(manifest)
      end

      Notifications::ManifestPublisher.call(event: :port_in_resubmitted, manifest:) if result.success?
      result
    end

    def capture_report_amendment_resubmittable?(manifest)
      manifest.capture_report_submitted? &&
        manifest.port_in_pending? &&
        manifest.capture_reports.any?(&:needs_amendment?)
    end

    def resubmit_capture_reports(manifest, actor:)
      ActiveRecord::Base.transaction do
        manifest.capture_reports.select(&:needs_amendment?).each do |report|
          CaptureReports::Resubmit.call(report, actor: actor).value!
        end
      end

      Success(manifest)
    end
  end
end
