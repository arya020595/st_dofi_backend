module Authentication
  # Sign-in for internal staff (see User.directory_managed).
  # Finds the local account, checks it may sign in, and asks the directory whether the password is right.
  # AD never creates users or assigns roles; PostgreSQL stays the source of truth for who exists and what they can do.
  #
  # Returns Success(user) or one of
  #   Failure(:not_applicable)        - not a staff account (unknown, Fisherman, Jetty Manager): not ours to decide
  #   Failure(:invalid_credentials)   - refuse; includes ineligible and ambiguous accounts (nothing is disclosed)
  #   Failure(:directory_unavailable) - the directory could not be asked
  # A staff account is never handed back to the local-password path, whatever the outcome.
  class OfficerLogin
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def initialize(config: DirectoryConfig.current, authenticator: nil, logger: ApplicationLogger)
      @config = config
      @authenticator = authenticator || (config.mock? ? MockLdapAuthenticator : LdapAuthenticator).new(config:)
      @logger = logger
    end

    def call(username:, password:)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      matches = staff_matching(username)
      return Failure(:not_applicable) if matches.empty?

      user, result, reason = decide(matches, password)
      log(user:, result:, reason:, started:)
      result
    end

    private

    attr_reader :config, :authenticator, :logger

    # [user, result, reason]: the reason names a refusal that happened here, before the directory was asked.
    def decide(matches, password)
      return [nil, Failure(:invalid_credentials), "ambiguous_username"] unless matches.one?

      authenticate(matches.first, password)
    end

    def staff_matching(typed)
      candidates = directory_username(typed).stored_candidates
      candidates.empty? ? [] : User.directory_managed.where(username: candidates).limit(2).to_a
    end

    def authenticate(user, password)
      return [user, Failure(:invalid_credentials), "ineligible_account"] unless user.kept? && user.active?

      short = directory_username(user.username).short
      return [user, Failure(:invalid_credentials), "invalid_stored_username"] if short.nil?

      result = authenticator.call(username: short, password:)
      [user, result.fmap { user }, nil]
    end

    def directory_username(text) = DirectoryUsername.new(text, domain: config.netbios_domain)

    def log(user:, result:, reason:, started:)
      outcome = result.success? ? "success" : "failure"
      logger.call(event: "ad.login", level: result.success? ? :info : :warn, user_id: user&.id,
                  params: { mode: config.mode, outcome:, reason: reason || (result.failure if result.failure?),
                            duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round })
    end
  end
end
