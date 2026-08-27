module BruneiIdSessions
  module CallbackRendering
    extend ActiveSupport::Concern

    def render_callback_for(user, verified_ic_number:, audience:)
      return render_callback_registration(verified_ic_number, audience) unless user
      return render_inactive_registration(user, verified_ic_number) if inactive_registration?(user)
      return render_callback_dashboard(user, verified_ic_number) if user.active?

      render_callback_registration_status(user, verified_ic_number)
    end

    def render_fisherman_callback(verified_ic_number)
      result = ::Fisherman::Authenticate.call(verified_ic_number: verified_ic_number)
      return render_callback_dashboard(result.value!, verified_ic_number) if result.success?

      render_fisherman_failure(result.failure, verified_ic_number)
    end

    def render_fisherman_failure(failure, verified_ic_number)
      reason, payload = failure.is_a?(Array) ? failure : [failure, {}]
      handler = fisherman_failure_handlers.fetch(reason, method(:render_unknown_fisherman_failure))
      handler.call(verified_ic_number, payload)
    end

    def fisherman_failure_handlers
      {
        not_found: method(:render_fisherman_account_not_provisioned),
        pending_approval: method(:render_pending_fisherman_registration),
        suspended: method(:render_suspended_fisherman_registration),
        revoked: method(:render_revoked_fisherman_registration),
        not_claimable: method(:render_fisherman_claim_failed),
        already_claimed: method(:render_fisherman_claim_failed),
        ic_mismatch: method(:render_fisherman_claim_failed)
      }
    end

    def render_pending_fisherman_registration(verified_ic_number, payload)
      render_callback_registration_status(payload.fetch(:user), verified_ic_number)
    end

    def render_suspended_fisherman_registration(verified_ic_number, payload)
      render_inactive_registration(payload.fetch(:user), verified_ic_number)
    end

    def render_revoked_fisherman_registration(verified_ic_number, payload)
      render_revoked_registration(payload.fetch(:user), verified_ic_number)
    end

    def inactive_registration?(user)
      user.inactive? || user.suspended?
    end
  end
end
