class DashboardPolicy < ApplicationPolicy
  private

  def permission_resource = "dashboard"
end
