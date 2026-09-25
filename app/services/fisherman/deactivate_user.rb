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
      return Failure(:not_fisherman) unless user.fisherman?
      return Failure(:invalid_transition) unless user.active?

      user.audit_comment = audit_comment("fisherman_deactivate", reason)
      user.deactivate!
      user.update!(fisherman_status: "inactive")
      Success(user)
    end
  end
end
