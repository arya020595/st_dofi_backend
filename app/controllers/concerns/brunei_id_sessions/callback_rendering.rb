module BruneiIdSessions
  module CallbackRendering
    extend ActiveSupport::Concern

    # Jetty Managers are created by a DoFi Officer only (User Management → External Users), so an unknown
    # IC is terminal — there is no self-registration to fall back to.
    def render_jetty_manager_callback(user, verified_ic_number)
      return render_jetty_manager_account_not_provisioned(verified_ic_number) unless user
      return render_inactive_registration(user, verified_ic_number) unless user.active?

      render_callback_dashboard(user, verified_ic_number)
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
        suspended: method(:render_suspended_fisherman_registration),
        revoked: method(:render_revoked_fisherman_registration),
        not_claimable: method(:render_fisherman_claim_failed),
        already_claimed: method(:render_fisherman_claim_failed),
        ic_mismatch: method(:render_fisherman_claim_failed)
      }
    end

    def render_suspended_fisherman_registration(verified_ic_number, payload)
      render_inactive_registration(payload.fetch(:user), verified_ic_number)
    end

    def render_revoked_fisherman_registration(verified_ic_number, payload)
      render_revoked_registration(payload.fetch(:user), verified_ic_number)
    end
  end
end
