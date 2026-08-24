module Fisherman
  class RejectProvisionalUser
    include Dry::Monads[:result]
    include AuditedOperation

    def self.call(...) = new.call(...)

    def call(user:, rejected_by:, approval_remark_id:, reason: nil)
      remark_result = ApprovalRemarks::FindApplicable.call(id: approval_remark_id, action: :reject)
      return Failure(remark_result.failure) if remark_result.failure?

      with_audited_user(rejected_by) do
        user.with_lock { reject_locked_user(user, remark_result.value!, reason) }
      end
    end

    private

    def reject_locked_user(user, approval_remark, reason)
      return Failure(:not_fins_approval_required_fisherman) unless user.fins_approval_required_fisherman?
      return Failure(:invalid_transition) unless user.may_reject_fisherman?

      user.rejection_reason = approval_remark.name
      user.audit_comment = audit_comment("fisherman_rejection", reason || approval_remark.name)
      user.reject_fisherman!
      Success(user)
    end
  end
end
