class CompanyProfilePolicy < ApplicationPolicy
  RESOURCE = "profiling".freeze

  def index?
    return user.permission?("#{RESOURCE}.view") if fisherman_platform?

    user.permission?("#{RESOURCE}.list", "#{RESOURCE}.view")
  end

  def show? = user.permission?("#{RESOURCE}.view")
  def create? = user.dofi_officer_platform? && user.permission?("#{RESOURCE}.create")

  def update?
    fisherman_platform? ? user.permission?("#{RESOURCE}.view") : user.permission?("#{RESOURCE}.update")
  end

  def destroy? = user.permission?("#{RESOURCE}.delete")

  class Scope < Scope
    def resolve
      return scope.kept if user.officer?

      scope.kept.where(id: user.company_profile_id)
    end
  end
end
