module BruneiIdSessions
  module ResponsePayloads
    extend ActiveSupport::Concern

    def callback_error_payload(error)
      { status: "fail", message: error.fetch(:message), code: error[:code] }
    end

    def inactive_registration_payload(user, verified_ic_number, message)
      {
        status: "fail",
        message: message,
        code: "inactive_registration",
        data: registration_status_payload(user, verified_ic_number)
      }
    end

    def not_provisioned_payload(verified_ic_number, code:, message:)
      { status: "fail", message: message, code: code, data: not_provisioned_data(verified_ic_number) }
    end

    def fisherman_claim_failed_payload(verified_ic_number)
      {
        status: "fail",
        message: "Fisherman account could not be claimed.",
        code: "fisherman_claim_failed",
        data: fisherman_claim_failed_data(verified_ic_number)
      }
    end

    def invalid_audience_payload
      { status: "fail", message: "Unsupported audience.", code: "unsupported_audience" }
    end

    def dashboard_payload(user, verified_ic_number)
      registration_status_payload(user, verified_ic_number).merge(
        next_action: "dashboard",
        access_token: request.env["warden-jwt_auth.token"]
      ).merge(
        Realtime::CableToken.issue(user)
      )
    end

    def registration_status_payload(user, verified_ic_number)
      registration_status_data(user, verified_ic_number).merge(brunei_id_profile_response(verified_ic_number))
    end

    def registration_status_data(user, verified_ic_number)
      {
        next_action: "registration_status",
        user: UserBlueprint.render_as_hash(user),
        ic_number: verified_ic_number,
        registration_status: user.lifecycle_status
      }
    end

    def not_provisioned_data(verified_ic_number)
      {
        next_action: "registration_status",
        ic_number: verified_ic_number,
        registration_status: "not_found"
      }.merge(brunei_id_profile_response(verified_ic_number))
    end

    def fisherman_claim_failed_data(verified_ic_number)
      {
        next_action: "registration_status",
        ic_number: verified_ic_number,
        registration_status: "claim_failed"
      }.merge(brunei_id_profile_response(verified_ic_number))
    end
  end
end
