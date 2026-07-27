class ManifestExpensePolicy < ApplicationPolicy
  RESOURCE = "manifest_expenses".freeze

  def show?   = user.permission?("#{RESOURCE}.view")
  def create? = user.permission?("#{RESOURCE}.create")
  def update? = user.permission?("#{RESOURCE}.update")
end
