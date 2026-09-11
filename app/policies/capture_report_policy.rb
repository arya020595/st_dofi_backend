class CaptureReportPolicy < ApplicationPolicy
  def resubmit? = permitted?("resubmit")

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope if user.dofi_officer_platform?

      scope.joins(:manifest).where(manifests: { company_profile_id: user.company_profile_id })
    end
  end

  private

  def permission_resource = "capture_reports"
end
