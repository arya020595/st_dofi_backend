class ManifestApprovalPolicy < ApplicationPolicy
  def tab_counts? = index?
  def approve? = permitted?("approve")
  def amendment? = permitted?("amendment")

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.kept
  end

  private

  def permission_resource = "manifest_approvals"
end
