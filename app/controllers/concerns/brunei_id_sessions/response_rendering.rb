module BruneiIdSessions
  module ResponseRendering
    extend ActiveSupport::Concern

    def render_callback_error(error)
      log_brunei_id_callback_result(callback_error_log(error))
      render json: callback_error_payload(error), status: error.fetch(:status)
    end

    def render_login_unauthorized(verified_ic_number)
      log_brunei_id_callback_result(login_unauthorized_log(verified_ic_number))
      render json: { status: "fail", message: "Account is inactive or unavailable." }, status: :unauthorized
    end

    def render_invalid_audience
      render json: invalid_audience_payload, status: :unprocessable_content
    end

    def render_callback_dashboard(user, verified_ic_number)
      sign_in(:user, user, store: false)
      log_brunei_id_callback_result(dashboard_log(user, verified_ic_number))
      render json: { status: "success", data: dashboard_payload(user, verified_ic_number) }, status: :ok
    end
  end
end
