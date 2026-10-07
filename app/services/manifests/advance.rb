module Manifests
  # Moves the overall manifest_status as far as the Port-Out / Port-In / Capture Report legs now allow.
  #
  # Port-In (Jetty Manager) and the Capture Reports (DoFi Officer) are reviewed in separate requests, so whichever
  # finishes last must move the manifest on; call this after any step that can settle a leg. The row is re-read
  # under a lock so it judges the other leg's committed state, not the instance this request loaded earlier —
  # otherwise two concurrent requests could each see the other's step as unfinished and leave a fully approved
  # manifest stuck. What happens next is decided by LifecycleRules#next_event.
  class Advance
    def self.call(...) = new.call(...)

    def call(manifest, actor: nil)
      manifest.with_lock do
        while (event = LifecycleRules.new(manifest).next_event)
          manifest.public_send(:"#{event}!", actor: actor)
          finish_completion(manifest) if event == :complete_manifest
        end
      end
      manifest
    end

    private

    def finish_completion(manifest)
      RecordFishingGearUsage.call(manifest)
      AmendmentSnapshot.clear_capture_report(manifest)
    end
  end
end
