module Manifests
  class SubmitPortOut
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:)
      manifest.with_lock do
        next Failure(manifest) unless manifest.may_submit_port_out?

        manifest.submit_port_out!(actor: actor)
        move_manifest_on(manifest, actor)
        notify_port_out_approvers(manifest) if manifest.port_out_pending?
        Success(manifest)
      end
    end

    private

    # Commercial waits for the Jetty Manager's review; small-scale needs no approval and goes straight to sea.
    def move_manifest_on(manifest, actor)
      if manifest.port_out_pending?
        manifest.begin_port_out_review!(actor: actor)
      else
        manifest.advance_to_sea!(actor: actor)
      end
    end

    def notify_port_out_approvers(manifest)
      Notifications::ManifestPublisher.enqueue(event: :port_out_review_required, manifest:)
    end
  end
end
