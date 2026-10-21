module Roles
  class EnsureFishermanAdminRole
    def self.call(...) = new.call(...)

    def call(company_profile)
      Role.find_or_create_by!(company_profile_id: company_profile.id, is_default_admin: true) do |role|
        role.name = "Admin"
        role.description = "Administrative access to this company's fisherman-platform data."
        role.platform_scope = Role::FISHERMAN_PLATFORM
        role.permissions = admin_permissions
      end
    rescue ActiveRecord::RecordNotUnique
      Role.find_by!(company_profile_id: company_profile.id, is_default_admin: true)
    end

    private

    def admin_permissions
      Permission.assignable_to(Role::FISHERMAN_PLATFORM)
    end
  end
end
