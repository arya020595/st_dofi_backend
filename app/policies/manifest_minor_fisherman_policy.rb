class ManifestMinorFishermanPolicy < ApplicationPolicy
  def show? = super && owns_record?
  def destroy? = super && owns_record?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope if user.dofi_officer_platform?

      scope.where(manifest_id: Manifest.where(company_profile_id: user.company_profile_id).select(:id))
    end
  end

  private

  def permission_resource = "manifest_minor_fishermen"

  def owns_record? = user.dofi_officer_platform? || record.manifest.company_profile_id == user.company_profile_id
end
