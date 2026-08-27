module Fisherman
  class Authenticate
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(verified_ic_number:)
      user = user_for(verified_ic_number)
      return Failure(:not_found) if user.nil?

      resolve_user(user, verified_ic_number)
    end

    private

    def user_for(verified_ic_number)
      User.kept.joins(:role).find_by(
        normalized_ic_number: IcNumbers::Normalize.call(verified_ic_number),
        roles: { platform_scope: Role::FISHERMAN_PLATFORM }
      )
    end

    def resolve_user(user, verified_ic_number)
      case user.fisherman_status
      when "pending_approval" then Failure([:pending_approval, { user: user }])
      when "claimable" then claim_user(user, verified_ic_number)
      when "active" then Success(user)
      when "suspended" then Failure([:suspended, { user: user }])
      when "revoked" then Failure([:revoked, { user: user }])
      else Failure([:not_claimable, { user: user }])
      end
    end

    def claim_user(user, verified_ic_number)
      ClaimAccount.call(user: user, verified_ic_number: verified_ic_number, verified_at: Time.current)
    end
  end
end
