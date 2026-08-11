module Users
  class Update
    include Dry::Monads[:result]
    include Users::RoleAssignmentValidation

    def self.call(...) = new.call(...)

    # assignable_roles required for the same reason as Users::Create — only checked when the update
    # actually touches role_id, so ordinary profile edits are unaffected.
    def call(user, attributes, assignable_roles:)
      if attributes.key?(:role_id) && !role_assignable?(user, attributes[:role_id], assignable_roles)
        return Failure(user)
      end
      return Success(user) if user.update(attributes)

      Failure(user)
    end
  end
end
