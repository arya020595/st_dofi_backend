module Fisherman
  class RejectProvisionalUser
    include Dry::Monads[:result]
    include AuditedOperation

    def self.call(...) = new.call(...)

    def call(user:, rejected_by:, approval_remark_id:, reason: nil)
      approval_remark = ApprovalRemark.kept.find_by(id: approval_remark_id)
      return invalid_remark_failure(user) if approval_remark.nil?

      with_audited_user(rejected_by) do
        user.with_lock { reject_locked_user(user, approval_remark, reason) }
      end
    end

    private

    def invalid_remark_failure(user)
      user.errors.add(:approval_remark_id, "is invalid")
      Failure(user)
    end

    def reject_locked_user(user, approval_remark, reason)
      return Failure(user) unless user.may_reject_fisherman?

      user.rejection_reason = approval_remark.name
      user.audit_comment = audit_comment("fisherman_rejection", reason || approval_remark.name)
      user.reject_fisherman!
      Success(user)
    end
  end
end
