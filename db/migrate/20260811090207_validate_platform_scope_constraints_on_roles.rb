class ValidatePlatformScopeConstraintsOnRoles < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :roles, name: "check_roles_platform_scope_not_null"
    validate_check_constraint :roles, name: "check_roles_platform_scope"
    validate_check_constraint :roles, name: "check_roles_company_profile_matches_platform_scope"
    # Safe after constraint validation: Postgres skips the table scan because the NOT NULL check
    # constraint already guarantees no nulls exist.
    safety_assured { change_column_null :roles, :platform_scope, false }
  end
end
