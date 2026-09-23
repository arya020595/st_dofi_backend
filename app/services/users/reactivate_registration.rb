module Users
  class ReactivateRegistration
    include Dry::Monads[:result]
    include Fisherman::AuditedOperation

    def self.call(...) = new.call(...)

    def call(user:, actor:, reason: nil)
      with_audited_user(actor) do
        User.transaction do
          reactivate_locked_user(User.lock.find(user.id), reason)
        end
      end
    end

    private

    def reactivate_locked_user(user, reason)
      return Failure(:not_fins_governed_jetty_manager) unless user.fins_governed_jetty_manager?
      return Failure(:revoked) if user.revoked_at.present?
      return Failure(:invalid_transition) unless user.may_reactivate?

      user.audit_comment = audit_comment("jetty_manager_reactivate", reason)
      user.reactivate!
      Success(user)
    end
  end
end
