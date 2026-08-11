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

      return false unless all_codes_exist?(role, permission_codes.map(&:to_s))

      no_cross_platform_codes?(role, permission_codes)
    end

    def all_codes_exist?(role, codes)
      unknown = codes - Permission.where(code: codes).pluck(:code)
      return true if unknown.empty?

      role.errors.add(:permission_codes, "includes unknown codes: #{unknown.join(', ')}")
      false
    end

    def no_cross_platform_codes?(role, permission_codes)
      allowed_scopes = [role.platform_scope, Permission::SHARED_PLATFORM]
      disallowed = Permission.where(code: permission_codes).where.not(platform_scope: allowed_scopes).pluck(:code)
      return true if disallowed.empty?

      role.errors.add(:permission_codes,
                      "includes codes not available to the #{role.platform_scope} platform: " \
                      "#{disallowed.join(', ')}")
      false
    end
  end
end
