class RocbnCompanyPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    # Officer-only lookup of an external registry. Its rows are not tenant data, so there is no company scoping,
    # only the platform gate and the registry's own soft delete.
    def resolve
      return scope.kept if user.dofi_officer_platform?

      scope.none
    end
  end

  private

  def permission_resource = "rocbn_companies"
end
