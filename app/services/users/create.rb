module Users
  class Create
    include Dry::Monads[:result]
    include Users::RoleAssignmentValidation

    def self.call(...) = new.call(...)

    # assignable_roles is required, never defaulted — the controller derives it from the acting
    # user's own context (Admin::UsersController passes Role.assignable_by_admin,
    # Fisherman::UsersController passes Role.assignable_by_fisherman(current_user.company_profile_id)),
    # so this service never has to know which platform it's being called from.
    def call(attributes, assignable_roles:, require_role: false)
      client_password = attributes[:password].presence
      password = client_password || SecureRandom.base64(24)
      password_confirmation = client_password ? attributes[:password_confirmation] : password

      user = User.new(attributes.except(:employee_id, :password, :password_confirmation)
                                 .merge(employee_id: SecureRandom.uuid, password: password,
                                        password_confirmation: password_confirmation))
      return Failure(user) unless role_assignable?(user, user.role_id, assignable_roles, require_role: require_role)
      return Success(user) if user.save

      Failure(user)
    end
  end
end
