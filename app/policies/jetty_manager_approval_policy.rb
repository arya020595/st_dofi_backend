class JettyManagerApprovalPolicy < ApplicationPolicy
  RESOURCE = "jetty_manager_approvals".freeze

  def index? = user.permission?("#{RESOURCE}.list", "#{RESOURCE}.view")
  def show? = user.permission?("#{RESOURCE}.view") && fins_target?
  def approve? = user.permission?("#{RESOURCE}.approve") && fins_target? && record.pending?
  def reject? = user.permission?("#{RESOURCE}.reject") && fins_target? && record.pending?
  def deactivate? = user.permission?("#{RESOURCE}.deactivate") && fins_target?
  def reactivate? = user.permission?("#{RESOURCE}.reactivate") && fins_target?
  def revoke? = user.permission?("#{RESOURCE}.revoke") && fins_target?

  class Scope < Scope
    def resolve
      scope.kept.where(role_id: jetty_manager_role&.id)
    end

    private

    def jetty_manager_role
      Role.find_by(kind: Role::JETTY_MANAGER)
    end
  end

  private

  def fins_target?
    record.respond_to?(:fins_governed_jetty_manager?) && record.fins_governed_jetty_manager?
  end
end
