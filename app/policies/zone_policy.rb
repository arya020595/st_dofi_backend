class ZonePolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.kept
  end

  private

  def permission_resource = "zones"
end
