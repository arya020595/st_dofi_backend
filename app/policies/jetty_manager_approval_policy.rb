class JettyManagerApprovalPolicy < ApplicationPolicy
  def show? = super && fins_target?
  def approve? = permitted?("approve") && fins_target? && record.pending?
  def reject? = permitted?("reject") && fins_target? && record.pending?
  def deactivate? = permitted?("deactivate") && fins_target?
  def reactivate? = permitted?("reactivate") && fins_target?
  def revoke? = permitted?("revoke") && fins_target?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.kept.where(role_id: jetty_manager_role&.id)
    end

    private

    def jetty_manager_role
      Role.find_by(kind: Role::JETTY_MANAGER)
    end
  end

  private

  def permission_resource = "jetty_manager_approvals"

  def fins_target?
    record.respond_to?(:fins_governed_jetty_manager?) && record.fins_governed_jetty_manager?
  end
end
