class PermissionPolicy < ApplicationPolicy
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
