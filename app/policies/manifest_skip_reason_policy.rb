class ManifestSkipReasonPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.kept
  end

  private

  def permission_resource = "skip_reasons"
end
