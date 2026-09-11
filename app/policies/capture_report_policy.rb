class CaptureReportPolicy < ApplicationPolicy
  def show? = super && owns_record?
  def update? = super && owns_record?
  def resubmit? = permitted?("resubmit") && owns_record?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope if user.dofi_officer_platform?

      scope.joins(:manifest).where(manifests: { company_profile_id: user.company_profile_id })
    end
  end

  private

  def permission_resource = "capture_reports"

  def owns_record? = user.dofi_officer_platform? || record.manifest.company_profile_id == user.company_profile_id
end
