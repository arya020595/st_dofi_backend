class ManifestPolicy < ApplicationPolicy
  RESOURCE = "manifests".freeze
  APPROVALS = "manifest_approvals".freeze

  def index? = user.permission?("#{RESOURCE}.list")
  def tab_counts? = index?
  def show? = user.permission?("#{RESOURCE}.view")
  def create? = user.permission?("#{RESOURCE}.create")
  def update? = user.permission?("#{RESOURCE}.update")
  def destroy? = user.permission?("#{RESOURCE}.delete")
  def offline_bundle? = user.permission?("#{RESOURCE}.offline_bundle")
  def submit_port_out? = user.permission?("#{RESOURCE}.submit_port_out")
  def resubmit_port_out? = user.permission?("#{RESOURCE}.resubmit_port_out")
  def submit_port_in? = user.permission?("#{RESOURCE}.submit_port_in")
  def resubmit_port_in? = user.permission?("#{RESOURCE}.resubmit_port_in")
  def skip_capture_report? = user.permission?("#{RESOURCE}.skip_capture_report")
  def approve_port_out? = user.permission?("#{APPROVALS}.approve")
  def request_amendment_port_out? = user.permission?("#{APPROVALS}.amendment")
  def approve_port_in? = user.permission?("#{APPROVALS}.approve")
  def request_amendment_port_in? = user.permission?("#{APPROVALS}.amendment")

  class Scope < Scope
    def resolve
      return scope.kept if user.dofi_officer_platform?

      scope.kept.where(company_profile_id: user.company_profile_id)
    end
  end
end
