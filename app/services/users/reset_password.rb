module Users
  class ResetPassword
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(token, password, password_confirmation)
      user = User.kept.with_reset_password_token(token)
      return Failure(token_error_user) unless user&.reset_password_period_valid?

      return Success(user) if user.reset_password(password, password_confirmation)

      Failure(user)
    end

    private

    def token_error_user
      User.new.tap { |u| u.errors.add(:reset_password_token, "is invalid or has expired") }
    end
  end
end
