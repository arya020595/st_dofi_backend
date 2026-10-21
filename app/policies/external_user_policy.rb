class ExternalUserPolicy < ApplicationPolicy
  def show? = super && governed_account?
  # Only Jetty Manager accounts are created/edited/removed here — Fisherman account data is owned by
  # Company Profiling (contact sync), so those rows stay list/view/deactivate/reactivate only.
  def update? = super && record.fins_governed_jetty_manager?
  def destroy? = super && record.fins_governed_jetty_manager?
  def deactivate? = permitted?("deactivate") && governed_account?
  def reactivate? = permitted?("reactivate") && governed_account?

  # One scope per External Users tab (Admin::ExternalUsers::JettyManagersController/FishermenController),
  # both under this one external_users.* resource — which tab a row shows up on is row visibility.
  class JettyManagerScope < ApplicationPolicy::Scope
    def resolve
      scope.kept.joins(:role).where(roles: { kind: Role::JETTY_MANAGER })
    end
  end

  class FishermanScope < ApplicationPolicy::Scope
    def resolve
      scope.kept.joins(:role)
           .where(provisioning_source: ::Fisherman::ProvisionUser::DOFI_COMPANY_PROFILE)
           .where(roles: { platform_scope: Role::FISHERMAN_PLATFORM })
           .where("roles.is_default = TRUE OR roles.is_default_admin = TRUE")
    end
  end

  private

  def permission_resource = "external_users"

  def governed_account? = record.fins_governed_fisherman? || record.fins_governed_jetty_manager?
end
