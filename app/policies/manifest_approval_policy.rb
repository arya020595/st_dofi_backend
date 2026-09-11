class ManifestApprovalPolicy < ApplicationPolicy
  def tab_counts? = index?
  def approve_port_out? = permitted?("approve_port_out")
  def request_amendment_port_out? = permitted?("request_amendment_port_out")
  def approve_port_in? = permitted?("approve_port_in")
  def request_amendment_port_in? = permitted?("request_amendment_port_in")

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.kept
  end

  private

  def permission_resource = "manifest_approvals"
end
