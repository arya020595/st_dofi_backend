class PermissionPolicy < ApplicationPolicy
  def index? = user.present?

  class Scope < Scope
    # This route deliberately sits outside both the admin/ and fisherman/ namespaces (see
    # config/routes.rb) — RequireAudience never runs for it, so the *scope*, not a controller-level
    # gate, is what keeps a fisherman from listing DoFi-Officer-only permission codes and vice versa.
    def resolve
      platform = user.role&.platform_scope
      return scope.none if platform.blank?

      scope.where(platform_scope: [platform, Permission::SHARED_PLATFORM])
    end
  end
end
