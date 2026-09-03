module BruneiIdSessions
  module LegacyRendering
    extend ActiveSupport::Concern

    def render_for(user, verified_ic_number:)
      return render_account_not_found unless user

      resolved_user = claim_legacy_fisherman_user(user, verified_ic_number)
      return render_status_only(user) unless resolved_user
      return render_status_only(resolved_user) unless login_allowed_for?(resolved_user)

      render_legacy_dashboard(resolved_user)
    end

    def claim_legacy_fisherman_user(user, verified_ic_number)
      return user unless user.fisherman? && user.fisherman_status == "claimable"

      result = ::Fisherman::ClaimAccount.call(user: user, verified_ic_number: verified_ic_number,
                                              verified_at: Time.current)
      result.success? ? result.value! : nil
    end

    def render_status_only(user)
      render json: { status: "success", data: UserBlueprint.render_as_hash(user) }, status: :ok
    end

    def render_legacy_dashboard(user)
      sign_in(:user, user, store: false)
      render json: legacy_dashboard_payload(user), status: :ok
    end

    def legacy_dashboard_payload(user)
      {
        status: "success",
        data: {
          access_token: request.env["warden-jwt_auth.token"],
          user: UserBlueprint.render_as_hash(user)
        }.merge(Realtime::CableToken.issue(user))
      }
    end

    def render_account_not_found
      render json: { status: "fail", message: I18n.t("errors.account_not_found") }, status: :not_found
    end

    def login_allowed_for?(user)
      user.fisherman? ? user.fisherman_status == "active" : user.active?
    end
  end
end
