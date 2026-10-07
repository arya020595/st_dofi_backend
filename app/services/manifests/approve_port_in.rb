module Manifests
  class ApprovePortIn
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    # The lock matters: the Jetty Manager's approval and a DoFi Officer's verification are separate requests, and
    # whichever runs last must see the other's committed state to complete the manifest.
    def call(manifest, actor:)
      result = manifest.with_lock do
        next Failure(manifest) unless manifest.may_approve_port_in?

        manifest.approve_port_in!(actor: actor)
        manifest.update!(port_in_amendment_remarks: nil)
        complete_manifest(manifest, actor)
        Success(manifest)
      end

      Notifications::ManifestPublisher.call(event: :port_in_approved, manifest:) if result.success?
      result
    end

    private

    def complete_manifest(manifest, actor)
      return unless manifest.may_complete_manifest?

      manifest.complete_manifest!(actor: actor)
      RecordFishingGearUsage.call(manifest)
    end
  end
end
