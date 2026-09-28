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
        registration_status: nil,
        error_code: error[:code],
        error_message: error.fetch(:message)
      }
    end

    def registration_status_log(user, verified_ic_number, message)
      {
        next_action: "registration_status",
        resolved_ic_number: verified_ic_number,
        registration_status: user.lifecycle_status,
        error_code: "inactive_registration",
        error_message: message
      }
    end

    def not_provisioned_log(verified_ic_number, code:, message:)
      {
        next_action: nil,
        resolved_ic_number: verified_ic_number,
        registration_status: "not_found",
        error_code: code,
        error_message: message
      }
    end

    def fisherman_claim_failed_log(verified_ic_number)
      {
        next_action: nil,
        resolved_ic_number: verified_ic_number,
        registration_status: "claim_failed",
        error_code: "fisherman_claim_failed",
        error_message: "Fisherman account could not be claimed."
      }
    end

    def dashboard_log(user, verified_ic_number)
      { next_action: "dashboard", resolved_ic_number: verified_ic_number, registration_status: user.lifecycle_status }
    end
  end
end
