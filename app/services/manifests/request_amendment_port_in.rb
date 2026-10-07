module Manifests
  class RequestAmendmentPortIn
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:, remarks:)
      result = manifest.with_lock do
        # Heals a manifest left behind its legs (Port-In pending, every report verified) before acting on it.
        manifest.begin_port_in_review!(actor: actor) if manifest.may_begin_port_in_review?
        next Failure(manifest) unless manifest.may_request_amendment_port_in?

        manifest.request_amendment_port_in!(actor: actor, remarks: remarks)
        manifest.update!(port_in_amendment_remarks: remarks)
        Success(manifest)
      end

      Notifications::ManifestPublisher.call(event: :port_in_amendment_required, manifest:) if result.success?
      result
    end
  end
end
