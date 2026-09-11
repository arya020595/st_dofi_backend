class FishCaptureDetailPolicy < ApplicationPolicy
  def bulk_sync? = permitted?("bulk_sync")

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope if user.dofi_officer_platform?

      scope.joins(capture_report: :manifest).where(manifests: { company_profile_id: user.company_profile_id })
    end
  end

  private

  def permission_resource = "fish_capture_details"
end
