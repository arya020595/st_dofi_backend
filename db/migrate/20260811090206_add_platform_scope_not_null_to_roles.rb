class AddPlatformScopeNotNullToRoles < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      change_column_null :roles, :platform_scope, false
      add_check_constraint :roles, "platform_scope IN ('fisherman', 'dofi_officer')", name: "check_roles_platform_scope"

      # Belt-and-suspenders alongside Role's app-level conditional presence/absence validations —
      # a fisherman-platform role must belong to a company, a dofi_officer-platform role must not.
      add_check_constraint :roles,
                           "(platform_scope = 'fisherman' AND company_profile_id IS NOT NULL) OR " \
                           "(platform_scope = 'dofi_officer' AND company_profile_id IS NULL)",
                           name: "check_roles_company_profile_matches_platform_scope"
    end
  end
end
