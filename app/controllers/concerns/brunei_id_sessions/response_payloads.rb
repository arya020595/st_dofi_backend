module BruneiIdSessions
  module ResponsePayloads
    extend ActiveSupport::Concern

    def callback_error_payload(error)
      { status: "fail", message: error.fetch(:message), code: error[:code] }
    end

    def invalid_audience_payload
      { status: "fail", message: "Unsupported audience.", code: "unsupported_audience" }
    end

    def dashboard_payload(user, verified_ic_number)
      {
        next_action: "dashboard",
        ic_number: verified_ic_number,
        user: UserBlueprint.render_as_hash(user),
        access_token: request.env["warden-jwt_auth.token"]
      }.merge(Realtime::CableToken.issue(user))
    end
  end
end
