class CompanyProfilePolicy < ApplicationPolicy
  RESOURCE = "company_profiles".freeze

  def index? = user.permission?("#{RESOURCE}.list")
  def show? = user.permission?("#{RESOURCE}.view")
  def create? = user.permission?("#{RESOURCE}.create")
  def update? = user.permission?("#{RESOURCE}.update")
  def destroy? = user.permission?("#{RESOURCE}.delete")

  class Scope < Scope
    def resolve
      return scope.kept if user.dofi_officer_platform?

      scope.kept.where(id: user.company_profile_id)
    end
  end
end
