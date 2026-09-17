module Users
  class Update
    include Dry::Monads[:result]
    include Users::RoleAssignmentValidation

    def self.call(...) = new.call(...)

    # assignable_roles required for the same reason as Users::Create — only checked when the update
    # actually touches role_id, so ordinary profile edits are unaffected.
    FISHERMAN_ACCOUNT_STATUSES = %w[active inactive].freeze

    def call(user, attributes, assignable_roles:, actor: nil)
      failure = update_failure(user, attributes, assignable_roles:, actor:)
      return Failure(failure) if failure

      return Success(user) if user.update(attributes)

      Failure(user)
    end

    private

    def fisherman_owner_management_failure(actor, user, role)
      ::Fisherman::OwnerManagementGuard.user_management_failure(actor: actor, target_user: user, role: role)
    end

    def update_failure(user, attributes, assignable_roles:, actor:)
      role = assignable_roles.find_by(id: attributes[:role_id]) if attributes.key?(:role_id)
      owner_failure = fisherman_owner_management_failure(actor, user, role)
      return user_with_base_error(user, owner_failure) if owner_failure
      return user_with_status_error(user) if invalid_status?(attributes, actor)
      return user if unassignable_role?(user, attributes, assignable_roles)

      nil
    end

    def unassignable_role?(user, attributes, assignable_roles)
      attributes.key?(:role_id) && !role_assignable?(user, attributes[:role_id], assignable_roles)
    end

    def user_with_base_error(user, failure)
      user.errors.add(:base, failure.to_s.humanize)
      user
    end

    def invalid_status?(attributes, actor)
      attributes[:status].present? && actor&.fisherman? && FISHERMAN_ACCOUNT_STATUSES.exclude?(attributes[:status])
    end

    def user_with_status_error(user)
      user.errors.add(:status, "must be active or inactive")
      user
    end
  end
end
