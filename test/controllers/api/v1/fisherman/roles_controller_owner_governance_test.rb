require "test_helper"

module Api
  module V1
    module Fisherman
      class RolesControllerOwnerGovernanceTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"
          @view_permission = create(:permission, code: "manifest_list.view",
                                                 platform_scope: Permission::SHARED_PLATFORM)
          @company_profile = create(:company_profile)
          permissions = role_management_permissions
          @owner_role = create(:role, :fisherman, company_profile: @company_profile, name: "Owner",
                                                  is_default: true, permissions: permissions)
          @admin_role = create(:role, :fisherman, company_profile: @company_profile, name: "Admin",
                                                  is_default_admin: true, permissions: permissions)
          @owner = create_active_owner
          @owner_headers = auth_headers_for(@owner, password: @password)
        end

        test "create rejects reserved Owner and Admin role names" do
          %w[Owner ADMIN].each do |name|
            assert_no_difference("Role.count") { create_role(name) }
            assert_response :unprocessable_content
            assert_includes response.parsed_body["errors"].join, "reserved"
          end
        end

        test "update refuses the company's default Owner role" do
          patch "/api/v1/fisherman/roles/#{@owner_role.id}",
                params: { role: { name: "Superadmin" } },
                headers: @owner_headers,
                as: :json

          assert_response :forbidden
        end

        test "destroy refuses the company's default Admin role" do
          delete "/api/v1/fisherman/roles/#{@admin_role.id}", headers: @owner_headers

          assert_response :forbidden
        end

        private

        def role_management_permissions
          %w[list view create update delete].map do |action|
            Permission.find_or_create_by!(code: "fisherman_roles.#{action}") do |permission|
              permission.name = "Fisherman roles - #{action.capitalize}"
              permission.platform_scope = Permission::FISHERMAN_PLATFORM
            end
          end
        end

        def create_active_owner
          timestamp = Time.current
          create(:user, role: @owner_role, company_profile: @company_profile, ic_number: SecureRandom.hex(5),
                        registration_type: "Commercial", password: @password, password_confirmation: @password,
                        fisherman_status: "active", claimed_at: timestamp, brunei_id_verified_at: timestamp)
        end

        def create_role(name)
          post "/api/v1/fisherman/roles", params: { role: { name: name }, permission_codes: [@view_permission.code] },
                                          headers: @owner_headers, as: :json
        end
      end
    end
  end
end
