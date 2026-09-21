class PermissionPolicy < ApplicationPolicy
  # Unconditional: every role needs to see its own platform's permission vocabulary (e.g. to power
  # the Role-creation UI's checklist of assignable codes) regardless of whether it holds
  # permissions.list. The real boundary is the platform-scoped row filter in Scope#resolve below.
  def index? = true

  class Scope < ApplicationPolicy::Scope
    def resolve
      platform = user.role&.platform_scope
      return scope.none if platform.blank?

      scope.where(code: Permission::Catalog.codes_for_platform(platform))
    end
  end

  private

  def permission_resource = "permissions"
end
