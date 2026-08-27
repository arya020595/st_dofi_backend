module Fisherman
  class RevokeUser
    include Dry::Monads[:result]
    include AuditedOperation

    def self.call(...) = new.call(...)

    def call(user:, actor:, approval_remark_id:, reason: nil)
      remark_result = ApprovalRemarks::FindApplicable.call(id: approval_remark_id, action: :revoke)
      return Failure(remark_result.failure) if remark_result.failure?

      with_audited_user(actor) do
        User.transaction do
          lock_owner_slot_if_needed(user) do
            user.with_lock { revoke_locked_user(user, actor, remark_result.value!, reason) }
          end
        end
      end
    end

    private

    def lock_owner_slot_if_needed(user, &block)
      return user.company_profile.with_lock(&block) if user.has_fisherman_owner_role? && user.company_profile

      block.call
    end

    def revoke_locked_user(user, actor, remark, reason)
      return Failure(:not_fins_governed_fisherman) unless user.fins_governed_fisherman?
      return Failure(:invalid_transition) unless revokable?(user)

      user.revoked_at = Time.current
      user.revoked_by = actor
      user.revocation_remark = remark
      user.revocation_comment = reason
      user.audit_comment = audit_comment("fisherman_revoke", reason || remark.name)
      user.revoke_fisherman!
      Success(user)
    end

    def revokable?(user)
      user.may_revoke_fisherman? && user.fisherman_status != "pending_approval"
    end
  end
end
