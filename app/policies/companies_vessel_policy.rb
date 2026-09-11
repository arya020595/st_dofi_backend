class CompaniesVesselPolicy < ApplicationPolicy
  def images? = permitted?("images")

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.kept if user.dofi_officer_platform?

      scope.kept.where(company_profile_id: user.company_profile_id)
    end
  end

  private

  def permission_resource = "companies_vessels"
end
