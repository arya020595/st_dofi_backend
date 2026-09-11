class EntityUserPolicy < ApplicationPolicy
  def users? = index?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.kept if user.dofi_officer_platform?

      scope.none
    end
  end

  private

  def permission_resource = "entity_users"
end
