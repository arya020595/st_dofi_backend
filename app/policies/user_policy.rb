class UserPolicy < ApplicationPolicy
  def show? = super && owns_record?
  def update? = super && owns_record?
  def destroy? = super && owns_record?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.kept.where(role_id: nil).or(scope.kept.where.not(role_id: Role.external.select(:id)))
    end
  end

  private

  def permission_resource = "dofi_officer_users"

  def owns_record? = record.role_id.nil? || !record.role&.external?
end
