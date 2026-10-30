module Users
  class Create
    include Dry::Monads[:result]
    include Users::RoleAssignmentValidation

    def self.call(...) = new.call(...)

    # assignable_roles is required, never defaulted — the controller derives it from the acting user's own context
    # (Admin::UsersController passes Role.assignable_by_admin), so this service never has to know which platform it's
    # being called from. Staff have no DoFi password (they sign in through Active Directory), so none is set here.
    def call(attributes, assignable_roles:)
      user = User.new(attributes.merge(employee_id: SecureRandom.uuid))
      return Failure(user) unless role_assignable?(user, user.role_id, assignable_roles)
      return Success(user) if user.save

      Failure(user)
    end
  end
end
