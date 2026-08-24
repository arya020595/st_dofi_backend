module Users
  class ApproveRegistration
    include Dry::Monads[:result]
    include Fisherman::AuditedOperation

    def self.call(...) = new.call(...)

    def call(user:, actor:, reason: "DoFI approval")
      with_audited_user(actor) do
        user.with_lock { approve_locked_user(user, reason) }
      end
    end

    private

    def approve_locked_user(user, reason)
      return Failure(:not_fins_governed_jetty_manager) unless user.fins_governed_jetty_manager?
      return Failure(:invalid_transition) unless user.may_approve?

      user.audit_comment = audit_comment("jetty_manager_approval", reason)
      user.approve!
      Success(user)
    end
  end
end
