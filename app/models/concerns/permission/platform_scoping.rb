module Permission::PlatformScoping
  extend ActiveSupport::Concern

  # Deliberately 3 values where Role::PLATFORM_SCOPES has 2 — a role always belongs to exactly one
  # platform, but a permission can be usable by both ("shared", e.g. dashboard.list). Do not
  # "simplify" this to reuse Role::PLATFORM_SCOPES.
  DOFI_OFFICER_PLATFORM = "dofi_officer".freeze
  FISHERMAN_PLATFORM = "fisherman".freeze
  SHARED_PLATFORM = "shared".freeze
  PLATFORM_SCOPES = [DOFI_OFFICER_PLATFORM, FISHERMAN_PLATFORM, SHARED_PLATFORM].freeze

  included do
    validates :platform_scope, presence: true, inclusion: { in: PLATFORM_SCOPES }
  end

  class_methods do
    # The permission codes a role on the given platform may be assigned — its own platform's codes,
    # plus anything shared. Used by Roles::Create/Update to reject cross-platform assignment, and by
    # Roles::EnsureFishermanOwnerRole/EnsureFishermanAdminRole to auto-provision a role's grants.
    # Filters via Permission::Catalog (the sole source of truth) rather than the persisted
    # platform_scope column, so a drifted/stale row can never leak a code across platforms.
    def assignable_to(role_platform_scope)
      where(code: Permission::Catalog.codes_for_platform(role_platform_scope))
    end
  end
end
