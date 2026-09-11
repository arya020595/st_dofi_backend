class FishermanApprovalPolicy < ApplicationPolicy
  def show? = super && fins_target?
  def approve? = permitted?("approve") && approval_target?
  def reject? = permitted?("reject") && approval_target?
  def deactivate? = permitted?("deactivate") && fins_target?
  def reactivate? = permitted?("reactivate") && fins_target?
  def revoke? = permitted?("revoke") && fins_target?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.kept
           .joins(:role)
           .where(provisioning_source: ::Fisherman::ProvisionUser::DOFI_COMPANY_PROFILE)
           .where(roles: { platform_scope: Role::FISHERMAN_PLATFORM })
           .where("roles.is_default = TRUE OR roles.is_default_admin = TRUE")
    end
  end

  private

  def permission_resource = "fisherman_approvals"

  def fins_target?
    record.respond_to?(:fins_governed_fisherman?) && record.fins_governed_fisherman?
  end

  def approval_target?
    record.respond_to?(:fins_approval_required_fisherman?) && record.fins_approval_required_fisherman?
  end
end
