module Manifests
  class SubmitPortOut
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:)
      result = manifest.with_lock do
        next Failure(manifest) unless manifest.may_submit_port_out?

        manifest.submit_port_out!(actor: actor)
        move_manifest_on(manifest, actor)
        Success(manifest)
      end

      notify_port_out_approvers(manifest) if result.success? && manifest.port_out_pending?
      result
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
      Notifications::ManifestPublisher.call(event: :port_out_review_required, manifest:)
    end
  end
end
