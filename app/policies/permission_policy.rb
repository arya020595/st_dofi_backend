class PermissionPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    # This route deliberately sits outside both the admin/ and fisherman/ namespaces (see
    # config/routes.rb) — RequireAudience never runs for it, so the *scope*, not a controller-level
    # gate, is what keeps a fisherman from listing DoFi-Officer-only permission codes and vice versa.
    # Filters via Permission::Catalog rather than the persisted platform_scope column, so a
    # drifted/stale row can never leak a code across platforms.
    def resolve
      platform = user.role&.platform_scope
      return scope.none if platform.blank?

      scope.where(code: Permission::Catalog.codes_for_platform(platform))
    end
  end

  private

  def permission_resource = "permissions"
end
