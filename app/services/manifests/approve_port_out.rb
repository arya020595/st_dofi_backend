module Manifests
  class ApprovePortOut
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:)
      manifest.with_lock do
        next Failure(manifest) unless manifest.may_approve_port_out?

        manifest.approve_port_out!(actor: actor)
        manifest.update!(port_out_amendment_remarks: nil)
        manifest.advance_to_sea!(actor: actor)
        Notifications::ManifestPublisher.enqueue(event: :port_out_approved, manifest:)
        Success(manifest)
      end
    end
  end
end
