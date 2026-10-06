module Manifests
  class RequestAmendmentPortIn
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:, remarks:)
      normalize_manifest_review_state!(manifest, actor: actor)
      return Failure(manifest) unless manifest.may_request_amendment_port_in?

      manifest.request_amendment_port_in!(actor: actor, remarks: remarks)
      Notifications::ManifestPublisher.call(event: :port_in_amendment_required, manifest:)
      Success(manifest)
    end

    private

    def normalize_manifest_review_state!(manifest, actor:)
      manifest.begin_port_in_review_if_ready!(actor: actor)
    end
  end
end
