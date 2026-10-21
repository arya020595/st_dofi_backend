class ZonePolicy < ApplicationPolicy
  include FishermanReadable

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.kept
  end

  private

  def permission_resource = "zones"
end
