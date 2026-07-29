class CompaniesDocumentApprovalPolicy < ApplicationPolicy
  RESOURCE = "companies_document_approvals".freeze

  def index?  = user.permission?("#{RESOURCE}.list", "#{RESOURCE}.view")
  def show?   = user.permission?("#{RESOURCE}.view")
  def approve? = user.permission?("#{RESOURCE}.approve")
  def request_amendment? = user.permission?("#{RESOURCE}.amendment")

  class Scope < Scope
    def resolve
      scope.kept
    end
  end
end
