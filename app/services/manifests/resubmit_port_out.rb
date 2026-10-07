module Manifests
  class ResubmitPortOut
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:)
      Transition.call(manifest, :resubmit_port_out, actor: actor).tap do |result|
        Notifications::ManifestPublisher.call(event: :port_out_resubmitted, manifest:) if result.success?
      end
    end
  end
end
