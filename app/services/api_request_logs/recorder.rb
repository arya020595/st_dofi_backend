module ApiRequestLogs
  # rubocop:disable Metrics/ClassLength
  class Recorder
    class << self
      def log_inbound(request:, response:, current_user:, controller_name:, exception: nil)
        ApiRequestLog.create!(
          body: inbound_body(request:, response:, current_user:, controller_name:, exception:),
          created_at: Time.current
        )
      rescue StandardError => e
        Rails.logger.error({ message: "Failed to persist inbound api_request_log", error_class: e.class.name,
                             error_message: e.message, request_id: request.request_id }.to_json)
      end

      # rubocop:disable Metrics/ParameterLists
      def log_outbound(provider:, method:, url:, request_body:, response_body:, status_code:, exception: nil)
        ApiRequestLog.create!(
          body: outbound_body(provider:, method:, url:, request_body:, response_body:, status_code:, exception:),
          created_at: Time.current
        )
      rescue StandardError => e
        Rails.logger.error({ message: "Failed to persist outbound api_request_log", error_class: e.class.name,
                             error_message: e.message, request_id: Current.request_id,
                             provider: provider }.to_json)
      end
      # rubocop:enable Metrics/ParameterLists

      private

      # rubocop:disable Metrics/MethodLength
      def inbound_body(request:, response:, current_user:, controller_name:, exception:)
        {
          request: {
            direction: "inbound",
            request_id: request.request_id,
            user_id: current_user&.id,
            controller_name: controller_name,
            method: request.request_method,
            base_url: request.base_url,
            path: request.path,
            params: sanitized_inbound_params(request),
            body: sanitized_inbound_request(request)
          },
          response: {
            status_code: exception.present? ? 500 : response.status,
            body: sanitized_response_body(exception.present? ? nil : response.body),
            error: serialized_error(exception)
          }
        }
      end
      # rubocop:enable Metrics/MethodLength

      # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
      def outbound_body(provider:, method:, url:, request_body:, response_body:, status_code:, exception:)
        {
          request: {
            direction: "outbound",
            provider: provider,
            request_id: Current.request_id,
            user_id: Current.user_id,
            method: method.to_s.upcase,
            base_url: parsed_base_url(url),
            path: parsed_path(url),
            params: parsed_outbound_params(url),
            body: ApiRequestLogs::Sanitizer.filter(request_body) || {}
          },
          response: {
            status_code: status_code,
            body: ApiRequestLogs::Sanitizer.filter(response_body) || {},
            error: serialized_error(exception)
          }
        }
      end
      # rubocop:enable Metrics/MethodLength, Metrics/ParameterLists

      def sanitized_inbound_request(request)
        payload = request.request_parameters.presence ||
                  request.filtered_parameters.except("controller", "action", "format")
        ApiRequestLogs::Sanitizer.filter(payload) || {}
      end

      def sanitized_inbound_params(request)
        payload = {
          query: request.query_parameters,
          path: request.path_parameters.except(:controller, :action, :format)
        }
        ApiRequestLogs::Sanitizer.filter(payload) || {}
      end

      def sanitized_response_body(body)
        parsed = parse_response_body(body)
        ApiRequestLogs::Sanitizer.filter(parsed) || {}
      end

      def parse_response_body(body)
        return if body.blank?

        JSON.parse(body)
      rescue JSON::ParserError
        { raw_body: body }
      end

      def parsed_base_url(url)
        uri = URI.parse(url)
        "#{uri.scheme}://#{uri.host}#{":#{uri.port}" if uri.port && uri.port != uri.default_port}"
      rescue URI::InvalidURIError
        nil
      end

      def parsed_path(url)
        uri = URI.parse(url)
        uri.path
      rescue URI::InvalidURIError
        url
      end

      def parsed_outbound_params(url)
        uri = URI.parse(url)
        payload = { query: Rack::Utils.parse_nested_query(uri.query.to_s) }
        ApiRequestLogs::Sanitizer.filter(payload) || {}
      rescue URI::InvalidURIError
        {}
      end

      def serialized_error(exception)
        return unless exception

        {
          class: exception.class.name,
          message: exception.message
        }
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
