module Manifests
  class RequestAmendmentPortIn
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:, remarks:)
      # Heals a manifest left behind its legs (Port-In pending, every report verified) before acting on it.
      manifest.advance_lifecycle!(actor: actor)
      return Failure(manifest) unless manifest.may_request_amendment_port_in?

      manifest.request_amendment_port_in!(actor: actor, remarks: remarks)
      Notifications::ManifestPublisher.call(event: :port_in_amendment_required, manifest:)
      Success(manifest)
    end
  end
end
