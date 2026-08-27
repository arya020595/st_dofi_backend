module ApiRequestLogs
  class InboundBody
    def initialize(attributes)
      @attributes = attributes
    end

    def call
      { request: request_payload, response: response_payload }
    end

    private

    attr_reader :attributes

    def request_payload
      base_request_payload.merge(params: sanitized_inbound_params, body: sanitized_inbound_request)
    end

    def base_request_payload
      {
        direction: "inbound",
        request_id: request.request_id,
        user_id: current_user&.id,
        controller_name: attributes[:controller_name],
        method: request.request_method,
        base_url: request.base_url,
        path: request.path
      }
    end

    def response_payload
      { status_code: status_code, body: sanitized_response_body, error: serialized_error }
    end

    def status_code
      exception.present? ? 500 : response.status
    end

    def sanitized_inbound_request
      payload = request.request_parameters.presence || filtered_request_parameters
      ApiRequestLogs::Sanitizer.filter(payload) || {}
    end

    def filtered_request_parameters
      request.filtered_parameters.except("controller", "action", "format")
    end

    def sanitized_inbound_params
      payload = { query: request.query_parameters, path: filtered_path_parameters }
      ApiRequestLogs::Sanitizer.filter(payload) || {}
    end

    def filtered_path_parameters
      request.path_parameters.except(:controller, :action, :format)
    end

    def sanitized_response_body
      ApiRequestLogs::Sanitizer.filter(parsed_response_body) || {}
    end

    def parsed_response_body
      return if response.body.blank? || exception.present?

      JSON.parse(response.body)
    rescue JSON::ParserError
      { raw_body: response.body }
    end

    def serialized_error
      return unless exception

      { class: exception.class.name, message: exception.message }
    end

    def request = attributes.fetch(:request)
    def response = attributes.fetch(:response)
    def current_user = attributes[:current_user]
    def exception = attributes[:exception]
  end
end
