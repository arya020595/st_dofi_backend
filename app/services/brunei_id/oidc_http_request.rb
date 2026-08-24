module BruneiId
  class OidcHttpRequest
    def initialize(connection:, attributes:)
      @connection = connection
      @attributes = attributes
    end

    def call
      response = perform_request
      parsed_body = parse_response_body(response.body)
      log_outbound_request(response.status, parsed_body)
      raise Faraday::BadRequestError unless response.success?

      parsed_body
    rescue Faraday::Error => e
      log_failed_request(e)
      raise
    ensure
      log_token_exchange_summary(parsed_body) if token_endpoint? && response&.success?
    end

    private

    attr_reader :connection, :attributes

    def perform_request
      connection.public_send(method, url) do |request|
        headers.each { |key, value| request.headers[key] = value }
        assign_body(request)
      end
    end

    def assign_body(request)
      return if body.blank?

      request.headers["Content-Type"] = "application/x-www-form-urlencoded"
      request.body = body
    end

    def log_failed_request(error)
      response = error.response || {}
      log_outbound_request(response[:status], parse_response_body(response[:body]), error)
    end

    def log_outbound_request(status_code, response_body, exception = nil)
      ApiRequestLogs::Recorder.log_outbound(
        provider: "brunei_id",
        method: method,
        url: url,
        request_body: body,
        response_body: response_body,
        status_code: status_code,
        exception: exception
      )
    end

    def parse_response_body(raw_body)
      return {} if raw_body.blank?

      JSON.parse(raw_body)
    rescue JSON::ParserError, TypeError
      { raw_body: raw_body }
    end

    def log_token_exchange_summary(response_body)
      Rails.logger.info(token_exchange_summary(response_body).to_json)
    end

    def token_exchange_summary(response_body)
      {
        provider: "brunei_id",
        token_exchange_success: true,
        token_response_keys: response_body.is_a?(Hash) ? response_body.keys : []
      }
    end

    def token_endpoint?
      endpoint == "token"
    end

    def method = attributes.fetch(:method)
    def url = attributes.fetch(:url)
    def endpoint = attributes.fetch(:endpoint)
    def body = attributes[:body]
    def headers = attributes.fetch(:headers, {})
  end
end
