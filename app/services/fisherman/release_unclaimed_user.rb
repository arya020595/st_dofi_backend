module Fisherman
  class ReleaseUnclaimedUser
    include Dry::Monads[:result]
    include AuditedOperation

    def self.call(...) = new.call(...)

    def call(user:, actor:, reason:)
      return Failure(:already_claimed) if user.claimed_at.present?

      with_audited_user(actor) do
        user.with_lock do
          return Failure(:already_claimed) if user.claimed_at.present?

          user.audit_comment = audit_comment("fisherman_unclaimed_release", reason)
          user.discard
          user.errors.empty? ? Success(user) : Failure(user)
        end
      end
    end
  end
end
