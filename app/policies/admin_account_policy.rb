class AdminAccountPolicy < ApplicationPolicy
  def show? = super && governed_account?
  def deactivate? = permitted?("deactivate") && governed_account?
  def reactivate? = permitted?("reactivate") && governed_account?

  class Scope < ApplicationPolicy::Scope
    def resolve
      fisherman_accounts.or(jetty_manager_accounts)
    end

    private

    def fisherman_accounts
      scope.kept.joins(:role)
           .where(provisioning_source: ::Fisherman::ProvisionUser::DOFI_COMPANY_PROFILE)
           .where(roles: { platform_scope: Role::FISHERMAN_PLATFORM })
           .where("roles.is_default = TRUE OR roles.is_default_admin = TRUE")
    end

    def jetty_manager_accounts
      scope.kept.joins(:role).where(roles: { kind: Role::JETTY_MANAGER })
    end
  end

  private

  def permission_resource = "admin_accounts"

  def governed_account?
    record.fisherman? ? record.fins_governed_fisherman? : record.fins_governed_jetty_manager?
  end
end
