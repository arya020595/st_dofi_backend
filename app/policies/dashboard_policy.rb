class DashboardPolicy < ApplicationPolicy
  RESOURCE = "dashboard".freeze

  def show? = user.permission?("#{RESOURCE}.view")
end
