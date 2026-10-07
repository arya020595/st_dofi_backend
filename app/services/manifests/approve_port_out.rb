module Manifests
  class ApprovePortOut
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:)
      Transition.call(manifest, :approve_port_out, actor: actor).tap do |result|
        Notifications::ManifestPublisher.call(event: :port_out_approved, manifest:) if result.success?
      end
    end
  end
end
