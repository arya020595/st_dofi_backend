class ApprovalRemarkPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.kept
  end

  private

  def permission_resource = "approval_remarks"
end
