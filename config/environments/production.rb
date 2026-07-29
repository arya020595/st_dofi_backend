require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on MinIO (S3-compatible; see config/storage.yml for options).
  config.active_storage.service = :minio

  # Public-read bucket for content where a leaked URL isn't a concern (see docs/minio/MINIO.md §2 and
  # config/storage.yml's minio_assets/minio_assets_public blocks) — a separate MinIO bucket with
  # separate scoped credentials from the private `minio:` service above, not just a different
  # prefix in the same bucket. Models opt in via `has_one_attached ..., service:
  # Rails.application.config.x.active_storage_public_service`.
  config.x.active_storage_public_service = :minio_assets

  # Both staging and production run behind a reverse proxy (nginx/Caddy) that terminates SSL —
  # bare dedicated servers have no managed load balancer to do this implicitly.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [:request_id]
  config.logger   = ActiveSupport::TaggedLogging.logger($stdout)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Durable cache store backed by Solid Cache (database-backed, no Redis).
  config.cache_store = :solid_cache_store

  # Durable, database-backed Active Job queue (Solid Queue, no Redis).
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [:id]

  # Enable DNS rebinding protection and other `Host` header attacks. Bare dedicated servers have
  # no managed cloud edge/load balancer providing this protection, unlike a typical PaaS. Set
  # APP_HOSTS (comma-separated) once the real domain is known; unset disables the check, same
  # as before.
  if ENV["APP_HOSTS"].present?
    config.hosts = ENV["APP_HOSTS"].split(",").map(&:strip)
    config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
  end
end
