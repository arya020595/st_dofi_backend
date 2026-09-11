class FishingGearDetailPolicy < ApplicationPolicy
  def show? = super && owns_record?
  def update? = super && owns_record?
  def destroy? = super && owns_record?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope if user.dofi_officer_platform?

      scope.joins(capture_report: :manifest).where(manifests: { company_profile_id: user.company_profile_id })
    end
  end

  private

  def permission_resource = "fishing_gear_details"

  def owns_record?
    user.dofi_officer_platform? || record.capture_report.manifest.company_profile_id == user.company_profile_id
  end
end
