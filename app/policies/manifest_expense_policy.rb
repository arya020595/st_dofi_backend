class ManifestExpensePolicy < ApplicationPolicy
  RESOURCE = "manifest_expenses".freeze

  def show?
    fisherman_platform? ? fisherman_manifest_readable? : user.permission?("#{RESOURCE}.view")
  end

  def create?
    fisherman_platform? ? fisherman_manifest_writeable? : user.permission?("#{RESOURCE}.create")
  end

  def update?
    fisherman_platform? ? fisherman_manifest_writeable? : user.permission?("#{RESOURCE}.update")
  end

  private

  def fisherman_manifest_readable?
    user.permission?("#{RESOURCE}.view") || fisherman_manifest_read?
  end

  def fisherman_manifest_writeable?
    user.permission?("#{RESOURCE}.create", "#{RESOURCE}.update") || fisherman_manifest_write?
  end
end
