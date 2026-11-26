module Users
  # Shared by Users::Create/Update — the one place that enforces "a user can only be assigned a role
  # from the roles available to the acting context." What's available on each platform is defined by
  # Role.assignable_by_admin/assignable_by_fisherman (see Role) — this module doesn't know or care
  # which platform called it, only whether the requested role_id is in the set it was handed.
  module RoleAssignmentValidation
    private

    def role_assignable?(user, role_id, assignable_roles)
      return true if role_id.blank? || assignable_roles.exists?(id: role_id)

      user.errors.add(:role_id, "is not a role available to you")
      false
    end
  end
end
