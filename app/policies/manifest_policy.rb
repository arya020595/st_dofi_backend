class ManifestPolicy < ApplicationPolicy
  LIST = "manifest_list".freeze
  FORM = "manifest_form".freeze
  APPROVALS = "manifest_approvals".freeze

  def index?  = user.permission?("#{LIST}.list", "#{APPROVALS}.list")
  def tab_counts? = index?
  def show?   = user.permission?("#{LIST}.view", "#{FORM}.view", "#{APPROVALS}.view")
  def create? = user.permission?("#{FORM}.create")
  def update? = user.permission?("#{LIST}.update")
  def fisherman_update? = user.permission?("#{FORM}.create")
  def destroy? = user.permission?("#{LIST}.delete")

  def submit_port_out? = user.permission?("#{FORM}.create")
  def resubmit_port_out? = user.permission?("#{FORM}.create")
  def approve_port_out? = user.permission?("#{APPROVALS}.approve")
  def request_amendment_port_out? = user.permission?("#{APPROVALS}.amendment")

  def submit_port_in? = user.permission?("#{FORM}.create")
  def resubmit_port_in? = user.permission?("#{FORM}.create")
  def approve_port_in? = user.permission?("#{APPROVALS}.approve")
  def request_amendment_port_in? = user.permission?("#{APPROVALS}.amendment")

  def skip_capture_report? = user.permission?("#{FORM}.create")
  def offline_bundle? = show?

  class Scope < Scope
    def resolve
      return scope.kept if user.dofi_officer_platform?

      scope.kept.where(company_profile_id: user.company_profile_id)
    end
  end
end
