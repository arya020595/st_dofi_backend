class CompaniesCrewPolicy < ApplicationPolicy
  def show? = super && owns_record?
  def update? = super && owns_record?
  def destroy? = super && owns_record?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.kept if user.dofi_officer_platform?

      scope.kept.where(company_profile_id: user.company_profile_id)
    end
  end

  private

  def permission_resource = "companies_crews"

  def owns_record? = user.dofi_officer_platform? || record.company_profile_id == user.company_profile_id
end
