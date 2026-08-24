class FishermanApprovalPolicy < ApplicationPolicy
  RESOURCE = "fisherman_approvals".freeze

  def index? = user.permission?("#{RESOURCE}.list", "#{RESOURCE}.view")
  def show? = user.permission?("#{RESOURCE}.view") && fins_target?
  def approve? = user.permission?("#{RESOURCE}.approve") && approval_target?
  def reject? = user.permission?("#{RESOURCE}.reject") && approval_target?
  def deactivate? = user.permission?("#{RESOURCE}.deactivate") && fins_target?
  def reactivate? = user.permission?("#{RESOURCE}.reactivate") && fins_target?
  def revoke? = user.permission?("#{RESOURCE}.revoke") && fins_target?

  class Scope < Scope
    def resolve
      scope.kept
           .joins(:role)
           .where(provisioning_source: ::Fisherman::ProvisionUser::DOFI_COMPANY_PROFILE)
           .where(roles: { platform_scope: Role::FISHERMAN_PLATFORM })
           .where("roles.is_default = TRUE OR roles.is_default_admin = TRUE")
    end
  end

  private

  def fins_target?
    record.respond_to?(:fins_governed_fisherman?) && record.fins_governed_fisherman?
  end

  def approval_target?
    record.respond_to?(:fins_approval_required_fisherman?) && record.fins_approval_required_fisherman?
  end
end
