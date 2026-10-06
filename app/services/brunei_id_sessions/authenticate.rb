module BruneiIdSessions
  class Authenticate
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def initialize(oidc_callback: BruneiId::OidcCallback, account_resolver: ResolveAccount,
                   logger: ApplicationLogger)
      @oidc_callback = oidc_callback
      @account_resolver = account_resolver
      @logger = logger
    end

    def call(audience:, **credentials)
      result = authenticate(audience:, **credentials)
      log_result(result, audience)
      result
    end

    private

    attr_reader :oidc_callback, :account_resolver, :logger

    def authenticate(audience:, **credentials)
      return unsupported_audience if ResolveAccount::AUDIENCES.exclude?(audience)

      verification = oidc_callback.call(**credentials)
      return verification if verification.failure?

      account_resolver.call(ic_number: verification.value!, audience:)
    end

    def log_result(result, audience)
      payload = result.success? ? result.value! : result.failure
      logger.call(event: "brunei_id.authentication", level: log_level(result), user_id: payload[:user]&.id,
                  params: { audience: ResolveAccount::AUDIENCES.include?(audience) ? audience : "unsupported",
                            outcome: result.success? ? "success" : "failure", reason: payload[:code] })
    end

    def log_level(result)
      return :info if result.success?

      result.failure[:status] == :internal_server_error ? :error : :warn
    end

    def unsupported_audience
      Failure(ResolveAccount::UNSUPPORTED_AUDIENCE_ERROR)
    end
  end
end
