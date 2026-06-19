class PermissionPolicy < ApplicationPolicy
  def index? = user.present?

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
