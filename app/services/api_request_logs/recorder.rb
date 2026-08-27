module ApiRequestLogs
  class Recorder
    class << self
      def log_inbound(**attributes)
        ApiRequestLog.create!(body: InboundBody.new(attributes).call, created_at: Time.current)
      rescue StandardError => e
        log_persistence_failure(e, attributes[:request], nil)
      end

      def log_outbound(**attributes)
        ApiRequestLog.create!(body: OutboundBody.new(attributes).call, created_at: Time.current)
      rescue StandardError => e
        log_persistence_failure(e, nil, attributes[:provider])
      end

      private

      def log_persistence_failure(error, request, provider)
        Rails.logger.error(failure_payload(error, request, provider).compact.to_json)
      end

      def failure_payload(error, request, provider)
        {
          message: "Failed to persist api_request_log",
          error_class: error.class.name,
          error_message: error.message,
          request_id: request&.request_id || Current.request_id,
          provider: provider
        }
      end
    end
  end
end
