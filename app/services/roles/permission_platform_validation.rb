module Roles
  # Shared by Roles::Create/Update — the one place that enforces "a role can only be assigned
  # permission codes belonging to its own platform, or shared codes." Without this, an admin request
  # could hand a Fisherman role a DoFi-Officer-only permission code (or vice versa) simply by passing
  # it in permission_codes; Pundit authorization alone doesn't catch this since it's a data-shape
  # concern, not an action-permission one.
  module PermissionPlatformValidation
    private

    def permissions_in_platform?(role, permission_codes)
      return true if permission_codes.blank?

      disallowed_codes = Permission.where(code: permission_codes)
                                   .where.not(platform_scope: [role.platform_scope, Permission::SHARED_PLATFORM])
                                   .pluck(:code)
      return true if disallowed_codes.empty?

      role.errors.add(:permission_codes,
                      "includes codes not available to the #{role.platform_scope} platform: " \
                      "#{disallowed_codes.join(', ')}")
      false
    end
  end
end
