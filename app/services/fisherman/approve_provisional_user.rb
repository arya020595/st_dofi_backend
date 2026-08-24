module Fisherman
  class ApproveProvisionalUser
    include Dry::Monads[:result]
    include AuditedOperation

    def self.call(...) = new.call(...)

    def call(user:, approved_by:, reason: "DoFI approval")
      with_audited_user(approved_by) do
        user.with_lock do
          return Failure(user) unless user.may_approve_fisherman?

          user.approved_at = Time.current
          user.approved_by = approved_by
          user.audit_comment = audit_comment("fisherman_approval", reason)
          user.approve_fisherman!
          Success(user)
        end
      end
    end
  end
end
