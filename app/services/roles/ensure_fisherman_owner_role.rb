module Roles
  class EnsureFishermanOwnerRole
    def self.call(...) = new.call(...)

    # Idempotent: the first person to register for a company creates it; everyone after reuses the
    # same row. Keyed on (company_profile_id, is_default) rather than name — the company can rename
    # their Owner role through the fisherman-side Roles UI, and a name-based lookup would silently
    # create a second "default" role the moment they did (see docs/registration/business-flow.md §9
    # for the prior incident this same mistake caused with a different column).
    #
    # Permissions are only assigned when the role is first created — a company that has since
    # customized its Owner role's permissions must not have them silently reset on the next
    # teammate's registration.
    def call(company_profile)
      Role.find_or_create_by!(company_profile_id: company_profile.id, is_default: true) do |role|
        role.name = "Owner"
        role.description = "Full access to this company's fisherman-platform data."
        role.platform_scope = Role::FISHERMAN_PLATFORM
        role.permissions = Permission.assignable_to(Role::FISHERMAN_PLATFORM)
      end
    rescue ActiveRecord::RecordNotUnique
      Role.find_by!(company_profile_id: company_profile.id, is_default: true)
    end
  end
end
