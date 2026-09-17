module User::AdminAccountFiltering
  extend ActiveSupport::Concern

  # Computed fields for Api::V1::Admin::AccountsController's category/status filters — a role's
  # kind/platform_scope determines which category an account belongs to (Jetty Manager and DoFi
  # Officer share platform_scope "dofi_officer", so kind must be checked first), and fisherman_status
  # only ever means "active"/"inactive" here for the two lifecycle states this endpoint covers;
  # pending_approval/claimable/revoked fishermen are governed through approvals/fishermen instead and
  # deliberately fall through to NULL so they never match either filter value.
  included do
    ransacker :account_category do
      Arel.sql(<<~SQL.squish)
        CASE
          WHEN roles.kind = 'Jetty Manager' THEN 'jetty_manager_account'
          WHEN roles.platform_scope = 'fisherman' THEN 'fisherman_account'
        END
      SQL
    end

    ransacker :account_status do
      Arel.sql(<<~SQL.squish)
        CASE
          WHEN roles.platform_scope = 'fisherman' AND users.fisherman_status = 'active' THEN 'active'
          WHEN roles.platform_scope = 'fisherman' AND users.fisherman_status = 'suspended' THEN 'inactive'
          WHEN roles.platform_scope = 'fisherman' THEN NULL
          ELSE users.status
        END
      SQL
    end
  end
end
