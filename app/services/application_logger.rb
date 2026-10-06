class ApplicationLogger
  LEVELS = %i[debug info warn error fatal].freeze
  SENSITIVE_PARAMS = %i[ic_number icnumber ic_no name subject sub contact_no phone address birthdate
                        headers body raw_body redirect_uri].freeze

  def self.call(...) = new.call(...)

  def initialize(logger: Rails.logger, clock: -> { Time.current })
    @logger = logger
    @clock = clock
    filters = Rails.application.config.filter_parameters + SENSITIVE_PARAMS
    @parameter_filter = ActiveSupport::ParameterFilter.new(filters)
  end

  def call(event:, params: {}, level: :info, request_id: Current.request_id, user_id: nil)
    level = level.to_sym if level.respond_to?(:to_sym)
    validate_arguments(level, event, params)

    logger.public_send(level) do
      { timestamp: clock.call.utc.iso8601(3), level:, event:, request_id:, user_id:,
        params: parameter_filter.filter(params) }.to_json
    end
  rescue IOError, SystemCallError
    # A broken log output must not change authentication or a business operation.
    false
  end

  private

  attr_reader :logger, :clock, :parameter_filter

  def validate_arguments(level, event, params)
    raise ArgumentError, "Unsupported log level" unless LEVELS.include?(level)
    unless event.is_a?(String) && /\A[a-z][a-z0-9_.]*\z/.match?(event)
      raise ArgumentError, "Event must be a fixed dotted name"
    end
    raise ArgumentError, "Params must be a Hash" unless params.is_a?(Hash)
  end
end
