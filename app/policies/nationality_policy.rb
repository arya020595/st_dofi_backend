class NationalityPolicy < ApplicationPolicy
  include FishermanReadable

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  private

  def permission_resource = "nationalities"
end
