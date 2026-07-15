module Manifests
  class RequestAmendmentPortIn
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:, remarks:)
      return Failure(manifest) unless manifest.may_request_amendment_port_in?

      manifest.request_amendment_port_in!(actor: actor, remarks: remarks)
      Success(manifest)
    end
  end
end
