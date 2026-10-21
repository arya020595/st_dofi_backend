module BruneiId
  class OidcHttpRequest
    def initialize(connection:, attributes:)
      @connection = connection
      @attributes = attributes
    end

    def call
      response = perform_request
      parsed_body = parse_response_body(response.body)
      raise Faraday::BadRequestError unless response.success?

      parsed_body
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

    def parse_response_body(raw_body)
      return {} if raw_body.blank?

      JSON.parse(raw_body)
    rescue JSON::ParserError, TypeError
      { raw_body: raw_body }
    end

    def method = attributes.fetch(:method)
    def url = attributes.fetch(:url)
    def body = attributes[:body]
    def headers = attributes.fetch(:headers, {})
  end
end
