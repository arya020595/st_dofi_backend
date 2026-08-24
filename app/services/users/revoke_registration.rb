module Users
  class RevokeRegistration
    include Dry::Monads[:result]
    include Fisherman::AuditedOperation

    def self.call(...) = new.call(...)

    def call(user:, actor:, approval_remark_id:, reason: nil)
      remark_result = ApprovalRemarks::FindApplicable.call(id: approval_remark_id, action: :revoke)
      return Failure(remark_result.failure) if remark_result.failure?

      with_audited_user(actor) do
        user.with_lock { revoke_locked_user(user, actor, remark_result.value!, reason) }
      end
    end

    private

    def revoke_locked_user(user, actor, remark, reason)
      return Failure(:not_fins_governed_jetty_manager) unless user.fins_governed_jetty_manager?
      return Failure(:invalid_transition) unless revokable?(user)

      assign_revocation_metadata(user, actor, remark, reason)
      user.audit_comment = audit_comment("jetty_manager_revoke", reason || remark.name)
      user.may_deactivate? ? user.deactivate! : user.save!
      Success(user)
    end

    def revokable?(user)
      user.revoked_at.blank? && %w[active suspended inactive].include?(user.status)
    end

    def assign_revocation_metadata(user, actor, remark, reason)
      user.revoked_at = Time.current
      user.revoked_by = actor
      user.revocation_remark = remark
      user.revocation_comment = reason
    end
  end
end
