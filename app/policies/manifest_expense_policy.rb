class ManifestExpensePolicy < ApplicationPolicy
  private

  def permission_resource = "manifest_expenses"
end
