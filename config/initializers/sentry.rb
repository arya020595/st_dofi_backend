if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.breadcrumbs_logger = %i[active_support_logger http_logger]
    config.environment = Rails.env
    config.traces_sample_rate = 0.1
    config.send_default_pii = false
  end
end
