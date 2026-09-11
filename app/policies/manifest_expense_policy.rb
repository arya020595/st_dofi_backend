class ManifestExpensePolicy < ApplicationPolicy
  def show? = super && owns_record?
  def create? = super && owns_record?
  def update? = super && owns_record?

  private

  def permission_resource = "manifest_expenses"

  def owns_record? = user.dofi_officer_platform? || record.manifest.company_profile_id == user.company_profile_id
end
