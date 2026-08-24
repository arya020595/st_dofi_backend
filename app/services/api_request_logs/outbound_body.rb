module ApiRequestLogs
  class OutboundBody
    def initialize(attributes)
      @attributes = attributes
    end

    def call
      { request: request_payload, response: response_payload }
    end

    private

    attr_reader :attributes

    def request_payload
      base_request_payload.merge(params: parsed_outbound_params, body: filtered_body(attributes[:request_body]))
    end

    def base_request_payload
      {
        direction: "outbound",
        provider: attributes[:provider],
        request_id: Current.request_id,
        user_id: Current.user_id,
        method: attributes[:method].to_s.upcase,
        base_url: parsed_base_url,
        path: parsed_path
      }
    end

    def response_payload
      { status_code: attributes[:status_code], body: filtered_body(attributes[:response_body]),
        error: serialized_error }
    end

    def filtered_body(body)
      ApiRequestLogs::Sanitizer.filter(body) || {}
    end

    def parsed_base_url
      uri = URI.parse(url)
      "#{uri.scheme}://#{uri.host}#{":#{uri.port}" if uri.port && uri.port != uri.default_port}"
    rescue URI::InvalidURIError
      nil
    end

    def parsed_path
      URI.parse(url).path
    rescue URI::InvalidURIError
      url
    end

    def parsed_outbound_params
      payload = { query: Rack::Utils.parse_nested_query(URI.parse(url).query.to_s) }
      ApiRequestLogs::Sanitizer.filter(payload) || {}
    rescue URI::InvalidURIError
      {}
    end

    def serialized_error
      return unless exception

      { class: exception.class.name, message: exception.message }
    end

    def url = attributes.fetch(:url)
    def exception = attributes[:exception]
  end
end
