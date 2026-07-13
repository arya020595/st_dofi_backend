source "https://rubygems.org"

ruby "3.4.7"

# Core
gem "bootsnap", require: false
gem "dotenv-rails"
gem "pg", "~> 1.6"
gem "puma", ">= 5.0"
gem "rails", "~> 8.1.3"
gem "tzinfo-data", platforms: %i[windows jruby]

# Use the database-backed adapters for Rails.cache and Active Job (no Redis)
gem "solid_cache"
gem "solid_queue"

# Authentication / Authorization
gem "devise"
gem "devise-jwt"
gem "pundit"

# State machines
gem "aasm", "~> 5.5", ">= 5.5.2"

# Service layer (Railway-oriented programming)
gem "dry-monads", "~> 1.9"

# Serialization
gem "blueprinter"

# Search / Pagination
gem "pagy"
gem "ransack"

# Soft delete / Audit trail
gem "audited", "~> 5.8"
gem "discard", "~> 1.4"

# File storage
gem "aws-sdk-s3", require: false
gem "cloudinary"
gem "image_processing", "~> 1.2"

# Migration safety
gem "strong_migrations"

# CORS / Rate limiting
gem "rack-attack"
gem "rack-cors"

# PDF / Excel export
gem "caxlsx"
gem "caxlsx_rails"
gem "prawn"
gem "prawn-table"

# Bilingual (EN/MS) model attributes
gem "mobility", "~> 1.3"

# HTTP client (BruneiID integration)
gem "faraday"
gem "jwt"

# Logging / Monitoring
gem "lograge"
gem "sentry-rails"
gem "sentry-ruby"

gem "bcrypt", "~> 3.1.22"

group :development, :test do
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "factory_bot_rails"
  gem "faker"
  gem "minitest-reporters"
  gem "rubocop", require: false
  gem "rubocop-minitest", require: false
  gem "rubocop-rails", require: false
end

group :development do
  gem "annotaterb"
  gem "bullet"
  gem "kamal", require: false
  gem "thruster", require: false
end
