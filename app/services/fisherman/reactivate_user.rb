module Fisherman
  class ReactivateUser
    include Dry::Monads[:result]
    include AuditedOperation

    def self.call(...) = new.call(...)

    def call(user:, actor:, reason: nil)
      with_audited_user(actor) do
        user.with_lock { reactivate_locked_user(user, reason) }
      end
    end

    private

    def reactivate_locked_user(user, reason)
      return Failure(:not_fisherman) unless user.fisherman?
      return Failure(:invalid_transition) unless user.inactive?

      user.audit_comment = audit_comment("fisherman_reactivate", reason)
      user.reactivate!
      user.update!(fisherman_status: "active")
      Success(user)
    end
  end
end
