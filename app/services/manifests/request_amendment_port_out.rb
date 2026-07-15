module Manifests
  class RequestAmendmentPortOut
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:, remarks:)
      return Failure(manifest) unless manifest.may_request_amendment_port_out?

      manifest.request_amendment_port_out!(actor: actor, remarks: remarks)
      Success(manifest)
    end
  end
end
