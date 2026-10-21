module Manifests
  class ResubmitPortOut
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:)
      manifest.with_lock do
        next Failure(manifest) unless manifest.may_resubmit_port_out?

        manifest.resubmit_port_out!(actor: actor)
        manifest.update!(port_out_amendment_remarks: nil)
        Notifications::ManifestPublisher.enqueue(event: :port_out_resubmitted, manifest:)
        Success(manifest)
      end
    end
  end
end
