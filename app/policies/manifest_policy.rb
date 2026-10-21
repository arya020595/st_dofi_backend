class ManifestPolicy < ApplicationPolicy
  def show? = super && owns_record?
  def update? = super && owns_record?
  def destroy? = super && owns_record?
  def tab_counts? = index?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.kept if user.dofi_officer_platform?

      scope.kept.where(company_profile_id: user.company_profile_id)
    end
  end

  private

  def permission_resource = "manifests"

  def owns_record? = user.dofi_officer_platform? || record_company_profile_id == user.company_profile_id

  # Also authorizes ManifestExpense/ManifestMinorFisherman records (dispatched via policy_class:),
  # which don't have their own catalog resource — manifests.* gates a manifest's whole child data.
  def record_company_profile_id
    record.is_a?(Manifest) ? record.company_profile_id : record.manifest.company_profile_id
  end
end
