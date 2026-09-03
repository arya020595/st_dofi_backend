module Manifests
  class ApprovePortOut
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:)
      return Failure(manifest) unless manifest.may_approve_port_out?

      manifest.approve_port_out!(actor: actor)
      Notifications::ManifestPublisher.call(event: :port_out_approved, manifest:)
      Success(manifest)
    end
  end
end
