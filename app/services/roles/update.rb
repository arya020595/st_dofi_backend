module Roles
  class Update
    include Dry::Monads[:result]
    include Roles::PermissionPlatformValidation

    def self.call(...) = new.call(...)

    # platform_scope/company_profile_id are re-forced from the caller on every update too, never
    # read from `attributes` — a role can never drift onto a different platform or company after
    # creation via this path. See Roles::Create for the fuller rationale, including why save! +
    # permission assignment run inside one transaction.
    def call(role, attributes, platform_scope:, permission_codes: nil, company_profile_id: nil)
      role.assign_attributes(attributes.merge(platform_scope:, company_profile_id:))
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
