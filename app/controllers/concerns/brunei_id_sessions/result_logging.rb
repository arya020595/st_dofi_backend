module BruneiIdSessions
  module ResultLogging
    extend ActiveSupport::Concern

    def log_brunei_id_callback_result(payload)
      Rails.logger.info(callback_log_payload(payload).compact.to_json)
    end

    def callback_log_payload(payload)
      {
        provider: "brunei_id",
        token_exchange_success: Current.brunei_id_token_response_keys.present?,
        token_response_keys: Current.brunei_id_token_response_keys || []
      }.merge(masked_callback_log_payload(payload))
    end

    def masked_callback_log_payload(payload)
      payload.merge(
        resolved_ic_number: ApiRequestLogs::Sanitizer.masked_ic_number(payload[:resolved_ic_number])
      )
    end

    def callback_error_log(error)
      {
        next_action: nil,
        resolved_ic_number: nil,
        error_code: error[:code],
        error_message: error.fetch(:message)
      }
    end

    def login_unauthorized_log(verified_ic_number)
      {
        next_action: nil,
        resolved_ic_number: verified_ic_number,
        error_code: "account_inactive_or_unavailable",
        error_message: "Account is inactive or unavailable."
      }
    end

    def dashboard_log(_user, verified_ic_number)
      { next_action: "dashboard", resolved_ic_number: verified_ic_number }
    end
  end
end
