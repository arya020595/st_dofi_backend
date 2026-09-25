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

    def resolve_user(user, _verified_ic_number)
      return Success(user) if user.active? && user.fisherman_status == "active"

      Failure(:inactive)
    end
  end
end
