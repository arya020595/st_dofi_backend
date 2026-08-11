require "test_helper"

module Api
  module V1
    module Admin
      class UsersControllerRoleRestrictionTest < ActionDispatch::IntegrationTest
        setup do
          password = "Password123!"
          admin_permissions = %w[list view create update delete].map do |action|
            Permission.find_or_create_by!(code: "dofi_officer_users.#{action}") do |permission|
              permission.name = "Dofi officer users - #{action.capitalize}"
            end
          end
          admin_role = create(:role, kind: Role::DOFI_OFFICER, permissions: admin_permissions)
          admin = create(:user, role: admin_role, position: "Administrator", unit: "HQ",
                                password: password, password_confirmation: password)
          @admin_headers = auth_headers_for(admin, password: password)
        end

        test "create rejects a Jetty Manager role_id" do
          jetty_manager_role = create(:role, kind: Role::JETTY_MANAGER, name: "Jetty Manager")

          post "/api/v1/admin/users", params: { user: { name: "Blocked", role_id: jetty_manager_role.id } },
                                      headers: @admin_headers, as: :json

          assert_response :unprocessable_content
          assert_includes response.parsed_body["errors"].join, "is not a role available to you"
        end

        test "create rejects a Fisherman role_id" do
          fisherman_role = create(:role, :fisherman, name: "Fisherman")

          post "/api/v1/admin/users", params: { user: { name: "Blocked", role_id: fisherman_role.id } },
                                      headers: @admin_headers, as: :json

          assert_response :unprocessable_content
          assert_includes response.parsed_body["errors"].join, "is not a role available to you"
        end

        test "create rejects an unassignable custom role_id (a nonexistent id)" do
          post "/api/v1/admin/users", params: { user: { name: "Blocked", role_id: SecureRandom.uuid } },
                                      headers: @admin_headers, as: :json

          assert_response :unprocessable_content
          assert_includes response.parsed_body["errors"].join, "is not a role available to you"
        end

        test "create allows a DoFi Officer role_id" do
          # DOFI_OFFICER is a singleton kind (unique index) — setup already created one for @admin,
          # so reuse it here rather than creating a second row, which the domain model forbids.
          officer_role = Role.find_by!(kind: Role::DOFI_OFFICER)

          post "/api/v1/admin/users", params: { user: { name: "Allowed Officer", position: "Administrator",
                                                        unit: "HQ", username: "mprt/allowed.officer",
                                                        role_id: officer_role.id } },
                                      headers: @admin_headers, as: :json

          assert_response :created
        end

        test "create allows a nil role_id" do
          post "/api/v1/admin/users", params: { user: { name: "No Role" } },
                                      headers: @admin_headers, as: :json

          assert_response :created
        end
      end
    end
  end
end
