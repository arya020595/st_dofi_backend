module Users
  class Update
    include Dry::Monads[:result]
    include Users::RoleAssignmentValidation

    def self.call(...) = new.call(...)

    # assignable_roles required for the same reason as Users::Create — only checked when the update
    # actually touches role_id, so ordinary profile edits are unaffected.
    def call(user, attributes, assignable_roles:, actor: nil)
      role = assignable_roles.find_by(id: attributes[:role_id]) if attributes.key?(:role_id)
      owner_failure = fisherman_owner_management_failure(actor, user, role)
      return Failure(user_with_base_error(user, owner_failure)) if owner_failure

      if attributes.key?(:role_id) && !role_assignable?(user, attributes[:role_id], assignable_roles)
        return Failure(user)
      end
      return Success(user) if user.update(attributes)

      Failure(user)
    end

    private

    def fisherman_owner_management_failure(actor, user, role)
      ::Fisherman::OwnerManagementGuard.user_management_failure(actor: actor, target_user: user, role: role)
    end

    def user_with_base_error(user, failure)
      user.errors.add(:base, failure.to_s.humanize)
      user
    end
  end
end
