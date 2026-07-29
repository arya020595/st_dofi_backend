class CompaniesDocumentPolicy < ApplicationPolicy
  RESOURCE = "companies_documents".freeze

  def index?  = user.permission?("#{RESOURCE}.list", "#{RESOURCE}.view")
  def show?   = user.permission?("#{RESOURCE}.view")
  def create? = user.permission?("#{RESOURCE}.create")
  def update? = user.permission?("#{RESOURCE}.update")

  class Scope < Scope
    def resolve
      return scope.kept if user.officer?

      scope.kept.where(company_profile_id: user.company_profile_id)
    end
  end
end
