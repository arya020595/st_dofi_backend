class CompaniesDocumentApprovalPolicy < ApplicationPolicy
  def approve? = permitted?("approve")
  def request_amendment? = permitted?("request_amendment")

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.kept
    end
  end

  private

  def permission_resource = "companies_document_approvals"
end
