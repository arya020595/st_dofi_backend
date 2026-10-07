module Manifests
  class RequestAmendmentPortIn
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:, remarks:)
      # Heals a manifest left behind its legs (Port-In pending, every report verified) before acting on it.
      Advance.call(manifest, actor: actor)
      Transition.call(manifest, :request_amendment_port_in, actor: actor, remarks: remarks).tap do |result|
        Notifications::ManifestPublisher.call(event: :port_in_amendment_required, manifest:) if result.success?
      end
    end
  end
end
