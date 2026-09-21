class CaptureReportPolicy < ApplicationPolicy
  def show? = super && owns_record?
  def update? = super && owns_record?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope if user.dofi_officer_platform?

      scope.joins(:manifest).where(manifests: { company_profile_id: user.company_profile_id })
    end
  end

  private

  def permission_resource = "capture_reports"

  def owns_record? = user.dofi_officer_platform? || record_company_profile_id == user.company_profile_id

  # Also authorizes FishCaptureDetail/FishingGearDetail records (dispatched via policy_class:), which
  # don't have their own catalog resource — capture_reports.* gates a capture report's whole child data.
  def record_company_profile_id
    if record.is_a?(CaptureReport)
      record.manifest.company_profile_id
    else
      record.capture_report.manifest.company_profile_id
    end
  end
end
