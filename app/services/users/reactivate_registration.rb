module Users
  class ReactivateRegistration
    include Dry::Monads[:result]
    include Fisherman::AuditedOperation

    def self.call(...) = new.call(...)

    def call(user:, actor:, reason: nil)
      with_audited_user(actor) do
        User.transaction do
          locked_user = User.lock.find(user.id)
          locked_user.clear_attribute_changes([:fisherman_status])
          reactivate_locked_user(locked_user, reason)
        end
      end
    end

    private

    def reactivate_locked_user(user, reason)
      return Failure(:not_jetty_manager) unless user.jetty_manager?
      return Failure(:invalid_transition) unless user.may_reactivate?

      user.audit_comment = audit_comment("jetty_manager_reactivate", reason)
      user.reactivate!
      Success(user)
    end
  end
end
