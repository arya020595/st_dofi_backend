module BruneiIdSessions
  module ResponsePayloads
    extend ActiveSupport::Concern

    def callback_error_payload(error)
      { status: "fail", message: error.fetch(:message), code: error[:code] }
    end

    def registration_payload(verified_ic_number, audience)
      { status: "success", data: registration_data(verified_ic_number, audience) }
    end

    def registration_data(verified_ic_number, audience)
      base_registration_data(verified_ic_number).merge(registration_callback_extras(verified_ic_number, audience))
    end

    def base_registration_data(verified_ic_number)
      { next_action: "registration", ic_number: verified_ic_number, registration_status: "not_found" }
    end

    def inactive_registration_payload(user, verified_ic_number, message)
      {
        status: "fail",
        message: message,
        code: "inactive_registration",
        data: registration_status_payload(user, verified_ic_number)
      }
    end

    def fisherman_not_provisioned_payload(verified_ic_number)
      {
        status: "fail",
        message: BruneiIdSessions::ResponseRendering::FISHERMAN_NOT_PROVISIONED_MESSAGE,
        code: "fisherman_account_not_provisioned",
        data: fisherman_not_provisioned_data(verified_ic_number)
      }
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

    def fisherman_not_provisioned_data(verified_ic_number)
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
