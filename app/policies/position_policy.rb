class PositionPolicy < ApplicationPolicy
  include FishermanReadable

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  private

  def permission_resource = "positions"
end
