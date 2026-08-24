require "test_helper"

module Api
  module V1
    module Fisherman
      class UsersControllerOwnerGovernanceTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"
          @company_profile = create(:company_profile)
          permissions = user_management_permissions
          @owner_role = create(:role, :fisherman, company_profile: @company_profile, name: "Owner",
                                                  is_default: true, permissions: permissions)
          @admin_role = create(:role, :fisherman, company_profile: @company_profile, name: "Admin",
                                                  is_default_admin: true, permissions: permissions)
          @owner = create_active_fisherman(@owner_role)
          @admin = create_active_fisherman(@admin_role)
          @target = create(:user, role: @admin_role, company_profile: @company_profile,
                                  ic_number: SecureRandom.hex(5), registration_type: "Commercial")
          @owner_headers = auth_headers_for(@owner, password: @password)
          @admin_headers = auth_headers_for(@admin, password: @password)
        end

        test "create rejects the company Owner role" do
          assert_no_difference("User.count") do
            post "/api/v1/fisherman/users", params: { user: owner_user_params },
                                            headers: @owner_headers, as: :json
          end

          assert_response :unprocessable_content
          assert_includes response.parsed_body["errors"].join, "Cannot assign owner role"
        end

        test "update rejects assigning Owner role through Fisherman User Management" do
          patch "/api/v1/fisherman/users/#{@target.id}", params: { user: { role_id: @owner_role.id } },
                                                         headers: @owner_headers, as: :json

          assert_response :unprocessable_content
          assert_includes response.parsed_body["errors"].join, "Cannot assign owner role"
        end

        test "update rejects managing an Owner target through Fisherman User Management" do
          patch "/api/v1/fisherman/users/#{@owner.id}", params: { user: { role_id: @admin_role.id } },
                                                        headers: @owner_headers, as: :json

          assert_response :forbidden
          assert_equal @owner_role.id, @owner.reload.role_id
        end

        test "destroy rejects Owner target even when actor is Owner" do
          delete "/api/v1/fisherman/users/#{@owner.id}", headers: @owner_headers

          assert_response :forbidden
          assert_not @owner.reload.discarded?
        end

        test "destroy rejects Owner target when actor is Admin with delete permission" do
          delete "/api/v1/fisherman/users/#{@owner.id}", headers: @admin_headers

          assert_response :forbidden
          assert_not @owner.reload.discarded?
        end

        private

        def user_management_permissions
          %w[list view create update delete].map do |action|
            Permission.find_or_create_by!(code: "fisherman_users.#{action}") do |permission|
              permission.name = "Fisherman users - #{action.capitalize}"
              permission.platform_scope = Permission::FISHERMAN_PLATFORM
            end
          end
        end

        def create_active_fisherman(role)
          timestamp = Time.current
          create(:user, role: role, company_profile: @company_profile, ic_number: SecureRandom.hex(5),
                        registration_type: "Commercial", password: @password, password_confirmation: @password,
                        fisherman_status: "active", claimed_at: timestamp, brunei_id_verified_at: timestamp)
        end

        def owner_user_params
          { name: "Blocked Owner", ic_number: SecureRandom.hex(5), registration_type: "Commercial",
            role_id: @owner_role.id }
        end
      end
    end
  end
end
