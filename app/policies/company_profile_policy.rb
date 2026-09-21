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

      scope.kept.where(id: user.company_profile_id)
    end
  end

  private

  def permission_resource = "company_profiles"

  def owns_record? = user.dofi_officer_platform? || record.id == user.company_profile_id
end
