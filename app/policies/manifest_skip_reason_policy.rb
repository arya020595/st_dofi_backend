class ManifestSkipReasonPolicy < ApplicationPolicy
  def index?
    return true if user.fisherman?

    super
  end

  def show?
    return true if user.fisherman?

    super
  end

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.kept
  end

  private

  def permission_resource = "manifest_skip_reasons"
end
