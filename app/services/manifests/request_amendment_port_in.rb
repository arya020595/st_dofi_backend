module Manifests
  class RequestAmendmentPortIn
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:, remarks:)
      manifest.with_lock do
        next Failure(manifest) unless manifest.may_request_amendment_port_in?

        # Heal the summary only after validating the requested action.
        manifest.begin_port_in_review!(actor: actor) if manifest.may_begin_port_in_review?

        manifest.request_amendment_port_in!(actor: actor, remarks: remarks)
        manifest.update!(port_in_amendment_remarks: remarks)
        Notifications::ManifestPublisher.enqueue(event: :port_in_amendment_required, manifest:)
        Success(manifest)
      end
    end
  end
end
