module Manifests
  # Fires one Port-Out / Port-In event and carries the manifest through everything that follows from it. The only
  # place that does so, so a transition can't skip the amendment snapshot or the status cascade.
  #
  #   Transition.call(manifest, :approve_port_in, actor: user)  # => Success(manifest) | Failure(manifest)
  #
  # Notifications are the caller's job (see Manifests::ApprovePortIn and friends).
  class Transition
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, event, actor: nil, remarks: nil)
      manifest.with_lock { fire(manifest, event, actor: actor, remarks: remarks) }
    end

    private

    def fire(manifest, event, actor:, remarks:)
      return Failure(manifest) unless manifest.public_send(:"may_#{event}?")

      manifest.public_send(:"#{event}!", actor: actor, remarks: remarks)
      AmendmentSnapshot.apply(manifest, event, remarks: remarks)
      Advance.call(manifest, actor: actor)
      Success(manifest)
    end
  end
end
