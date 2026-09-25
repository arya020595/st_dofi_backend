module Users
  class DeactivateRegistration
    include Dry::Monads[:result]
    include Fisherman::AuditedOperation

    def self.call(...) = new.call(...)

    def call(user:, actor:, reason: nil)
      with_audited_user(actor) do
        User.transaction do
          locked_user = User.lock.find(user.id)
          locked_user.clear_attribute_changes([:fisherman_status])
          deactivate_locked_user(locked_user, reason)
        end
      end
    end

    private

    def deactivate_locked_user(user, reason)
      return Failure(:not_jetty_manager) unless user.jetty_manager?
      return Failure(:invalid_transition) unless user.may_deactivate?

      user.audit_comment = audit_comment("jetty_manager_deactivate", reason)
      user.deactivate!
      Success(user)
    end
  end
end
