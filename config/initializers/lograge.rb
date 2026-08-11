Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new
  parameter_filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

  config.lograge.custom_options = lambda do |event|
    {
      request_id: event.payload[:request_id],
      user_id: event.payload[:user_id],
      params: parameter_filter.filter(event.payload[:params]&.except("controller", "action"))
    }
  end
end
