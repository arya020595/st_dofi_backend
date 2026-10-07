module BruneiIdSessions
  class MockAuthenticate
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def initialize(account_resolver: ResolveAccount, account_claimer: Fisherman::ClaimAccount,
                   logger: ApplicationLogger)
      @account_resolver = account_resolver
      @account_claimer = account_claimer
      @logger = logger
    end

    def call(ic_number:, audience: nil)
      return Failure(status: :not_found, message: "Not found.") unless Rails.configuration.x.brunei_id_mock_enabled
      return Failure(status: :unauthorized, message: "Identity verification failed.") if ic_number.blank?

      result = resolve_account(ic_number, audience)
      log_result(result, audience)
      result
    end

    private

    attr_reader :account_resolver, :account_claimer, :logger

    def resolve_account(ic_number, audience)
      return account_resolver.call(ic_number:, audience:) if ResolveAccount::AUDIENCES.include?(audience)

      user = User.kept.find_by(normalized_ic_number: IcNumbers::Normalize.call(ic_number))
      return Failure(status: :not_found, message: I18n.t("errors.account_not_found")) unless user

      result = claim_if_needed(user, ic_number)
      kind = result.success? && login_allowed_for?(result.value!) ? :mock_dashboard : :mock_status
      Success(kind:, user: result.success? ? result.value! : user)
    end

    def claim_if_needed(user, ic_number)
      return Success(user) unless user.fisherman? && user.fisherman_status == "claimable"

      account_claimer.call(user:, verified_ic_number: ic_number, verified_at: Time.current)
    end

    def login_allowed_for?(user)
      user.fisherman? ? user.fisherman_status == "active" : user.active?
    end

    def log_result(result, audience)
      payload = result.success? ? result.value! : result.failure
      logger.call(event: "brunei_id.mock_authentication", level: result.success? ? :info : :warn,
                  user_id: payload[:user]&.id,
                  params: { audience: ResolveAccount::AUDIENCES.include?(audience) ? audience : "unscoped",
                            outcome: result.success? ? "success" : "failure", kind: payload[:kind],
                            reason: payload[:code] })
    end
  end
end
