class CompanyProfilePolicy < ApplicationPolicy
  def index?
    return true if user.fisherman?

    super
  end

  def show?
    return owns_record? if user.fisherman?

    super
  end

  def create? = user.fisherman? || super
  def update? = user.fisherman? ? owns_record? : super && owns_record?
  def destroy? = user.fisherman? ? owns_record? : super && owns_record?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.kept if user.dofi_officer_platform?

      scope.kept.where(scoped_company_profile_column => user.company_profile_id)
    end

    private

    # This scope also gates CompaniesCrew/CompaniesVessel/CompaniesDocument/CompaniesFishingGear —
    # everything CompanyProfilePolicy authorizes on behalf of, not just CompanyProfile itself.
    # `scope` may be a bare class (no #klass) or a relation/association (has #klass), depending on
    # the call site, so it can't be assumed to always respond to #klass.
    def scoped_company_profile_column
      scope_class = scope.is_a?(Class) ? scope : scope.klass
      scope_class == CompanyProfile ? :id : :company_profile_id
    end
  end

  private

  def permission_resource = "company_profiles"

  def owns_record? = user.dofi_officer_platform? || record_company_profile_id == user.company_profile_id

  # This policy also authorizes CompaniesCrew/CompaniesVessel/CompaniesDocument/CompaniesFishingGear/
  # CompanyProfileContact records (dispatched via policy_class:), which don't have their own catalog
  # resource — company_profiles.* is the single permission gate for a company's whole profile.
  def record_company_profile_id
    record.is_a?(CompanyProfile) ? record.id : record.company_profile_id
  end
end
