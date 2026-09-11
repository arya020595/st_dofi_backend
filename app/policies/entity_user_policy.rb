class EntityUserPolicy < ApplicationPolicy
  RESOURCE = "dofi_officer_users".freeze

  def index? = user.permission?("#{RESOURCE}.list", "#{RESOURCE}.view")
  alias users? index?

  class Scope < Scope
    def resolve
      return scope.kept if user.dofi_officer_platform?

      scope.none
    end
  end
end
