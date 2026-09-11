class CompanyProfilePolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.kept if user.dofi_officer_platform?

      scope.kept.where(id: user.company_profile_id)
    end
  end

  private

  def permission_resource = "company_profiles"
end
