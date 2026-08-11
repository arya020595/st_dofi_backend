class FishermanApprovalPolicy < ApplicationPolicy
  RESOURCE = "fisherman_approvals".freeze

  def index? = user.permission?("#{RESOURCE}.list", "#{RESOURCE}.view")
  def show? = user.permission?("#{RESOURCE}.view")
  def approve? = user.permission?("#{RESOURCE}.approve")
  def reject? = user.permission?("#{RESOURCE}.approve")

  class Scope < Scope
    def resolve
      scope.kept.where(role_id: Role.where(platform_scope: Role::FISHERMAN_PLATFORM).select(:id))
    end
  end
end
