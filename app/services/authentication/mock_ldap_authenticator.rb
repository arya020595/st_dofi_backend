module Authentication
  # Local/staging stand-in for LdapAuthenticator (AD_MODE=mock), same contract: any username is accepted when the
  # password equals AD_MOCK_PASSWORD. The fixed password below makes the directory "unavailable" on demand so the
  # 503 path can be exercised without taking AD down. It is only ever chosen by OfficerLogin when the mode is mock.
  class MockLdapAuthenticator
    include Dry::Monads[:result]

    UNAVAILABLE_PASSWORD = "simulate-ad-unavailable".freeze

    def self.call(...) = new.call(...)

    def initialize(config: DirectoryConfig.current)
      @config = config
    end

    def call(username:, password:)
      return Failure(:invalid_credentials) if username.blank? || password.blank?
      return Failure(:directory_unavailable) if config.problems.any? || password == UNAVAILABLE_PASSWORD

      return Success(:authenticated) if ActiveSupport::SecurityUtils.secure_compare(password, config.mock_password)

      Failure(:invalid_credentials)
    end

    private

    attr_reader :config
  end
end
