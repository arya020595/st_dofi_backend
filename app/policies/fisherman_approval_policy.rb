class FishermanApprovalPolicy < ApplicationPolicy
  RESOURCE = "fisherman_approvals".freeze

  def index? = user.permission?("#{RESOURCE}.list", "#{RESOURCE}.view")
  def show? = user.permission?("#{RESOURCE}.view")
  def approve? = user.permission?("#{RESOURCE}.approve")
  def reject? = user.permission?("#{RESOURCE}.approve")

  class Scope < Scope
    def resolve
      scope.kept.where(role_id: fisherman_role&.id)
    end

    private

    def fisherman_role
      Role.find_by(kind: Role::FISHERMAN)
    end
  end
end
