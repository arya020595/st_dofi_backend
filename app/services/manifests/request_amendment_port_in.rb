module Manifests
  class RequestAmendmentPortIn
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:, remarks:)
      normalize_manifest_review_state!(manifest, actor: actor)
      return not_ready(manifest) unless manifest.awaiting_port_in_approval?
      return Failure(manifest) unless manifest.may_request_amendment_port_in?

      manifest.request_amendment_port_in!(actor: actor, remarks: remarks)
      Notifications::ManifestPublisher.call(event: :port_in_amendment_required, manifest:)
      Success(manifest)
    end

    private

    def normalize_manifest_review_state!(manifest, actor:)
      return unless manifest.capture_report_submitted?
      return unless manifest.port_in_pending?
      return unless manifest.capture_reports.exists?
      return unless manifest.capture_reports.all?(&:verified?)
      return unless manifest.may_begin_port_in_review?

      manifest.begin_port_in_review!(actor: actor)
    end

    def not_ready(manifest)
      manifest.errors.add(:base, "Capture reports must all be verified before amending port-in")
      Failure(manifest)
    end
  end
end
