module Fisherman
  class DeactivateUser
    include Dry::Monads[:result]
    include AuditedOperation

    def self.call(...) = new.call(...)

    def call(user:, actor:, reason: nil)
      with_audited_user(actor) do
        user.with_lock { deactivate_locked_user(user, reason) }
      end
    end

    private

    def deactivate_locked_user(user, reason)
      return Failure(:not_fins_governed_fisherman) unless user.fins_governed_fisherman?
      return Failure(:invalid_transition) unless user.may_suspend_fisherman?

      user.audit_comment = audit_comment("fisherman_deactivate", reason)
      user.suspend_fisherman!
      Success(user)
    end
  end
end
