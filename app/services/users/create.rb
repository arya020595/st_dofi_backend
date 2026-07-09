module Users
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(attributes)
      password = SecureRandom.base64(24)
      user = User.new(attributes.except(:employee_id, :password, :password_confirmation)
                                 .merge(employee_id: next_employee_id, password: password,
                                        password_confirmation: password))
      return external_role_failure(user) if user.role&.external?
      return Success(user) if user.save

      Failure(user)
    end

    private

    def external_role_failure(user)
      user.errors.add(:role_id, "cannot be a self-registration-only role (Jetty Manager or Fisherman)")
      Failure(user)
    end

    def next_employee_id
      next_num = User.where("employee_id LIKE ?", "DOF-%")
                     .maximum("CAST(SUBSTRING(employee_id FROM 5) AS INTEGER)") || 0
      format("DOF-%03d", next_num + 1)
    end
  end
end
