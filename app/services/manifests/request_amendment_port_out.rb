module Manifests
  class RequestAmendmentPortOut
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:, remarks:)
      result = manifest.with_lock do
        next Failure(manifest) unless manifest.may_request_amendment_port_out?

        manifest.request_amendment_port_out!(actor: actor, remarks: remarks)
        manifest.update!(port_out_amendment_remarks: remarks)
        Success(manifest)
      end

      Notifications::ManifestPublisher.call(event: :port_out_amendment_required, manifest:) if result.success?
      result
    end
  end
end
