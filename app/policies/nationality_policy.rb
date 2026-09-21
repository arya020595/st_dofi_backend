class NationalityPolicy < ApplicationPolicy
  def index?
    return true if user.fisherman?

    super
  end

  def show?
    return true if user.fisherman?

    super
  end

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  private

  def permission_resource = "nationalities"
end
