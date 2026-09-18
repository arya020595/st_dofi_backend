class ManifestApprovalPolicy < ApplicationPolicy
  def tab_counts? = index?
  def process_port_out? = permitted?("process_port_out")
  def process_port_in? = permitted?("process_port_in")

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.kept
  end

  private

  def permission_resource = "manifest_approvals"
end
