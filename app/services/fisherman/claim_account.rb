module Fisherman
  class ClaimAccount
    include Dry::Monads[:result]
    include AuditedOperation

    def self.call(...) = new.call(...)

    def call(user:, verified_ic_number:, verified_at:)
      user.with_lock do
        eligibility_failure = claim_eligibility_failure(user, verified_ic_number)
        return Failure(eligibility_failure) if eligibility_failure

        activate_claimed_user(user, verified_at)
      end
    end

    private

    def claim_eligibility_failure(user, verified_ic_number)
      return :not_claimable unless user.may_claim_fisherman?
      return :already_claimed if user.claimed_at.present?

      :ic_mismatch unless matching_ic?(user, verified_ic_number)
    end

    def matching_ic?(user, verified_ic_number)
      user.normalized_ic_number == IcNumbers::Normalize.call(verified_ic_number)
    end

    def activate_claimed_user(user, verified_at)
      user.claimed_at = Time.current
      user.brunei_id_verified_at = verified_at
      user.audit_comment = audit_comment("fisherman_claim", "BruneiID IC verified")
      user.claim_fisherman!
      Success(user)
    end
  end
end
