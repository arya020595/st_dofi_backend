class ManifestPolicy < ApplicationPolicy
  def tab_counts? = index?
  def offline_bundle? = permitted?("offline_bundle")
  def submit_port_out? = permitted?("submit_port_out")
  def resubmit_port_out? = permitted?("resubmit_port_out")
  def submit_port_in? = permitted?("submit_port_in")
  def resubmit_port_in? = permitted?("resubmit_port_in")
  def skip_capture_report? = permitted?("skip_capture_report")

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.kept if user.dofi_officer_platform?

      scope.kept.where(company_profile_id: user.company_profile_id)
    end
  end

  private

  def permission_resource = "manifests"
end
