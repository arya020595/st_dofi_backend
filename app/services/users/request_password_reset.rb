module Users
  class RequestPasswordReset
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    # Always returns Success, even when no user matches the email, so callers can't use this
    # endpoint to enumerate registered addresses.
    def call(email)
      user = User.kept.find_by(email: email)
      return Success() unless user

      raw_token = user.send_reset_password_instructions
      UserMailer.reset_password_instructions(user, raw_token).deliver_later

      Success()
    end
  end
end
