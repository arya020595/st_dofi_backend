module Manifests
  class SubmitPortOut
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:)
      Transition.call(manifest, :submit_port_out, actor: actor).tap do |result|
        if result.success? && manifest.port_out_pending?
          Notifications::ManifestPublisher.call(event: :port_out_review_required, manifest:)
        end
      end
    end
  end
end
