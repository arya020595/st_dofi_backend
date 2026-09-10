class CompanyProfileContactPolicy < ApplicationPolicy
  RESOURCE = "company_profile_contacts".freeze

  def create? = user.permission?("#{RESOURCE}.create")
  def update? = user.permission?("#{RESOURCE}.update")
  def destroy? = user.permission?("#{RESOURCE}.delete")
end
