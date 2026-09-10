module Permission::PlatformScoping
  extend ActiveSupport::Concern

  # Deliberately 3 values where Role::PLATFORM_SCOPES has 2 — a role always belongs to exactly one
  # platform, but a permission can be usable by both ("shared", e.g. companies_crews.create, used by
  # both a fisherman's own self-service form and an officer profiling on their behalf via the same
  # dual-mounted controller). Do not "simplify" this to reuse Role::PLATFORM_SCOPES.
  DOFI_OFFICER_PLATFORM = "dofi_officer".freeze
  FISHERMAN_PLATFORM = "fisherman".freeze
  SHARED_PLATFORM = "shared".freeze
  PLATFORM_SCOPES = [DOFI_OFFICER_PLATFORM, FISHERMAN_PLATFORM, SHARED_PLATFORM].freeze

  included do
    validates :platform_scope, presence: true, inclusion: { in: PLATFORM_SCOPES }
  end

  class_methods do
    # The permission codes a role on the given platform may be assigned — its own platform's codes,
    # plus anything shared. Used by Roles::Create/Update to reject cross-platform assignment.
    def assignable_to(role_platform_scope) = where(platform_scope: [role_platform_scope, SHARED_PLATFORM])
  end
end
