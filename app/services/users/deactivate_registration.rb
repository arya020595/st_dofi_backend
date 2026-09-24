module Users
  class DeactivateRegistration
    include Dry::Monads[:result]
    include Fisherman::AuditedOperation

    def self.call(...) = new.call(...)

    def call(user:, actor:, reason: nil)
      with_audited_user(actor) do
        user.with_lock { deactivate_locked_user(user, reason) }
      end
    end

    private

    def deactivate_locked_user(user, reason)
      return Failure(:not_fins_governed_jetty_manager) unless user.fins_governed_jetty_manager?
      return Failure(:invalid_transition) unless user.may_deactivate?

      user.audit_comment = audit_comment("jetty_manager_deactivate", reason)
      user.deactivate!
      Success(user)
    end
  end
end
