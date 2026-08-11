class AddPlatformScopeNotNullToRoles < ActiveRecord::Migration[8.1]
  # Belt-and-suspenders alongside Role's app-level conditional presence/absence validations.
  # All three constraints are added NOT VALID so they don't require a full table scan / ACCESS
  # EXCLUSIVE lock — validation is deferred to the next migration (ValidatePlatformScopeConstraintsOnRoles),
  # matching the same pattern used for the company_profile_id FK in migrations 090201/090202.
  def change
    add_check_constraint :roles, "platform_scope IS NOT NULL",
                         name: "check_roles_platform_scope_not_null", validate: false
    add_check_constraint :roles, "platform_scope IN ('fisherman', 'dofi_officer')",
                         name: "check_roles_platform_scope", validate: false
    add_check_constraint :roles,
                         "(platform_scope = 'fisherman' AND company_profile_id IS NOT NULL) OR " \
                         "(platform_scope = 'dofi_officer' AND company_profile_id IS NULL)",
                         name: "check_roles_company_profile_matches_platform_scope", validate: false
  end
end
