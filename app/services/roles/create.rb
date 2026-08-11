module Roles
  class Create
    include Dry::Monads[:result]
    include Roles::PermissionPlatformValidation

    def self.call(...) = new.call(...)

    # platform_scope/company_profile_id are required keywords, never read from `attributes` — the
    # controller derives them from the acting user's own context (Admin::RolesController always
    # passes "dofi_officer"; Fisherman::RolesController always passes "fisherman" + its own
    # company_profile_id), so a role can never end up on the wrong platform or another company.
    #
    # save! + permission assignment run inside one transaction (matching Manifests::Create's
    # save! + SetCrew.call precedent) — a role must never persist with an incomplete permission set
    # if the assignment step fails partway through.
    def call(attributes, platform_scope:, permission_codes: nil, company_profile_id: nil)
      role = Role.new(attributes.merge(platform_scope:, company_profile_id:))
      return Failure(role) unless permissions_in_platform?(role, permission_codes)

      ActiveRecord::Base.transaction do
        role.save!
        role.permissions = Permission.where(code: permission_codes) if permission_codes
      end
      Success(role)
    rescue ActiveRecord::RecordInvalid
      Failure(role)
    end
  end
end
