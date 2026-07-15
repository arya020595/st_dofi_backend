module Users
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(attributes)
      client_password = attributes[:password].presence
      password = client_password || SecureRandom.base64(24)
      password_confirmation = client_password ? attributes[:password_confirmation] : password

      user = User.new(attributes.except(:employee_id, :password, :password_confirmation)
                                 .merge(employee_id: SecureRandom.uuid, password: password,
                                        password_confirmation: password_confirmation))
      return external_role_failure(user) if user.role&.external?
      return Success(user) if user.save

      Failure(user)
    end

    private

    def external_role_failure(user)
      user.errors.add(:role_id, "cannot be a self-registration-only role (Jetty Manager or Fisherman)")
      Failure(user)
    end
  end
end
