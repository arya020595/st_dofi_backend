module BruneiIdSessions
  module ResponseRendering
    extend ActiveSupport::Concern

    FISHERMAN_NOT_PROVISIONED_MESSAGE = "No Fisherman account has been provisioned for this IC number. " \
                                        "Please contact DoFI or your company administrator.".freeze
    JETTY_MANAGER_NOT_PROVISIONED_MESSAGE = "No Jetty Manager account has been provisioned for this IC number. " \
                                            "Please contact DoFI.".freeze

    def render_callback_error(error)
      log_brunei_id_callback_result(callback_error_log(error))
      render json: callback_error_payload(error), status: error.fetch(:status)
    end

    def render_inactive_registration(user, verified_ic_number)
      message = "Registration is not active."
      log_brunei_id_callback_result(registration_status_log(user, verified_ic_number, message))
      render json: inactive_registration_payload(user, verified_ic_number, message), status: :unprocessable_content
    end

    def render_revoked_registration(user, verified_ic_number)
      render_inactive_registration(user, verified_ic_number)
    end

    def render_fisherman_account_not_provisioned(verified_ic_number, _payload = nil)
      render_account_not_provisioned(verified_ic_number, code: "fisherman_account_not_provisioned",
                                                         message: FISHERMAN_NOT_PROVISIONED_MESSAGE)
    end

    def render_jetty_manager_account_not_provisioned(verified_ic_number)
      render_account_not_provisioned(verified_ic_number, code: "jetty_manager_account_not_provisioned",
                                                         message: JETTY_MANAGER_NOT_PROVISIONED_MESSAGE)
    end

    def render_account_not_provisioned(verified_ic_number, code:, message:)
      log_brunei_id_callback_result(not_provisioned_log(verified_ic_number, code:, message:))
      render json: not_provisioned_payload(verified_ic_number, code:, message:), status: :not_found
    end

    def render_unknown_fisherman_failure(verified_ic_number, _payload = nil)
      render_fisherman_claim_failed(verified_ic_number)
    end

    def render_fisherman_claim_failed(verified_ic_number, _payload = nil)
      log_brunei_id_callback_result(fisherman_claim_failed_log(verified_ic_number))
      render json: fisherman_claim_failed_payload(verified_ic_number), status: :unprocessable_content
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
