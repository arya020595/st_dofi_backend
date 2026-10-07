module Manifests
  class RequestAmendmentPortOut
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:, remarks:)
      Transition.call(manifest, :request_amendment_port_out, actor: actor, remarks: remarks).tap do |result|
        Notifications::ManifestPublisher.call(event: :port_out_amendment_required, manifest:) if result.success?
      end
    end
  end
end
