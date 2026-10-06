module BruneiIdSessions
  class ResolveAccount
    include Dry::Monads[:result]

    AUDIENCES = %w[fisherman jetty_manager].freeze
    UNSUPPORTED_AUDIENCE_ERROR = {
      status: :unprocessable_content, code: "unsupported_audience", message: "Unsupported audience."
    }.freeze

    def self.call(...) = new.call(...)

    def initialize(fisherman_authenticator: Fisherman::Authenticate)
      @fisherman_authenticator = fisherman_authenticator
    end

    def call(ic_number:, audience:)
      case audience
      when "fisherman" then authenticate_fisherman(ic_number)
      when "jetty_manager" then authenticate_jetty_manager(ic_number)
      else Failure(UNSUPPORTED_AUDIENCE_ERROR)
      end
    end

    private

    attr_reader :fisherman_authenticator

    def authenticate_fisherman(ic_number)
      result = fisherman_authenticator.call(verified_ic_number: ic_number)
      return Success(kind: :dashboard, user: result.value!, ic_number:) if result.success?

      reason, payload = result.failure.is_a?(Array) ? result.failure : [result.failure, {}]
      case reason
      when :not_found then not_provisioned(ic_number, "fisherman")
      when :suspended, :revoked then inactive_registration(payload.fetch(:user), ic_number)
      else
        Failure(status: :unprocessable_content, code: "fisherman_claim_failed",
                message: "Fisherman account could not be claimed.", kind: :claim_failed, ic_number:)
      end
    end

    def authenticate_jetty_manager(ic_number)
      user = User.kept.joins(:role).find_by(normalized_ic_number: IcNumbers::Normalize.call(ic_number),
                                            roles: { kind: Role::JETTY_MANAGER })
      return not_provisioned(ic_number, "jetty_manager") unless user
      return inactive_registration(user, ic_number) unless user.active?

      Success(kind: :dashboard, user:, ic_number:)
    end

    def inactive_registration(user, ic_number)
      Failure(status: :unprocessable_content, code: "inactive_registration", message: "Registration is not active.",
              kind: :registration_status, user:, ic_number:)
    end

    def not_provisioned(ic_number, audience)
      message = if audience == "fisherman"
                  "No Fisherman account has been provisioned for this IC number. " \
                    "Please contact DoFI or your company administrator."
                else
                  "No Jetty Manager account has been provisioned for this IC number. Please contact DoFI."
                end
      Failure(status: :not_found, code: "#{audience}_account_not_provisioned", message:, kind: :not_found, ic_number:)
    end
  end
end
