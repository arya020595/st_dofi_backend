module Rocbn
  # Base of every model backed by the external ROCBN company registry. Connects through config/rocbn.yml rather
  # than config/database.yml (see that file for why), as a connection named "rocbn". Nothing here touches the
  # network: the pool is only registered, so the app boots, and keeps serving everything else, without the registry.
  # An external database must not inherit what ApplicationRecord configures for the primary one.
  class BaseRecord < ActiveRecord::Base # rubocop:disable Rails/ApplicationRecord
    self.abstract_class = true

    # What a registry that is down, slow or misconfigured raises. Controllers turn these into a 503.
    UNAVAILABLE_ERRORS = [
      ActiveRecord::ConnectionNotEstablished, ActiveRecord::QueryAborted, ActiveRecord::NoDatabaseError
    ].freeze

    establish_connection(
      ActiveRecord::DatabaseConfigurations::HashConfig.new(
        Rails.env, "rocbn", Rails.application.config_for(:rocbn).to_h
      )
    )
  end
end
