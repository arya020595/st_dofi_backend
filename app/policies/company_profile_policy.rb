class CompanyProfilePolicy < ApplicationPolicy
  def show? = super && owns_record?
  def update? = super && owns_record?
  def destroy? = super && owns_record?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.kept if user.dofi_officer_platform?

      scope.kept.where(id: user.company_profile_id)
    end
  end

  private

  def permission_resource = "company_profiles"

  def owns_record? = user.dofi_officer_platform? || record.id == user.company_profile_id
end
