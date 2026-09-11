class ManifestPolicy < ApplicationPolicy
  def show? = super && owns_record?
  def update? = super && owns_record?
  def destroy? = super && owns_record?
  def tab_counts? = index?
  def offline_bundle? = permitted?("offline_bundle") && owns_record?
  def submit_port_out? = permitted?("submit_port_out") && owns_record?
  def resubmit_port_out? = permitted?("resubmit_port_out") && owns_record?
  def submit_port_in? = permitted?("submit_port_in") && owns_record?
  def resubmit_port_in? = permitted?("resubmit_port_in") && owns_record?
  def skip_capture_report? = permitted?("skip_capture_report") && owns_record?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.kept if user.dofi_officer_platform?

      scope.kept.where(company_profile_id: user.company_profile_id)
    end
  end

  private

  def permission_resource = "manifests"

  def owns_record? = user.dofi_officer_platform? || record.company_profile_id == user.company_profile_id
end
