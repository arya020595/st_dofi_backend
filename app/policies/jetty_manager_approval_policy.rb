class JettyManagerApprovalPolicy < ApplicationPolicy
  RESOURCE = "jetty_manager_approvals".freeze

  def index? = user.permission?("#{RESOURCE}.list", "#{RESOURCE}.view")
  def show? = user.permission?("#{RESOURCE}.view")
  def approve? = user.permission?("#{RESOURCE}.approve")
  def reject? = user.permission?("#{RESOURCE}.approve")

  class Scope < Scope
    def resolve
      scope.kept.where(role_id: jetty_manager_role&.id)
    end

    private

    def jetty_manager_role
      Role.find_by(kind: Role::JETTY_MANAGER)
    end
  end
end
