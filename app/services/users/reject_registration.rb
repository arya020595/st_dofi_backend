module Users
  class RejectRegistration
    include Dry::Monads[:result]
    include Fisherman::AuditedOperation

    def self.call(...) = new.call(...)

    def call(user, approval_remark_id:, actor: nil, reason: nil)
      remark_result = ApprovalRemarks::FindApplicable.call(id: approval_remark_id, action: :reject)
      return Failure(remark_result.failure) if remark_result.failure?

      with_audited_user(actor) do
        user.with_lock { reject_locked_user(user, remark_result.value!, reason) }
      end
    end

    private

    def reject_locked_user(user, approval_remark, reason)
      return Failure(:not_fins_governed_jetty_manager) unless user.fins_governed_jetty_manager?
      return Failure(:invalid_transition) unless user.may_reject?

      user.rejection_reason = approval_remark.name
      user.audit_comment = audit_comment("jetty_manager_rejection", reason || approval_remark.name)
      user.reject!
      Success(user)
    end
  end
end
