require "test_helper"

module Api
  module V1
    module Admin
      class RolesControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          @view_permission = Permission.find_or_create_by!(code: "manifest_list.view") do |permission|
            permission.name = "Manifest list - View"
            permission.platform_scope = Permission::SHARED_PLATFORM
          end
          role_permissions = %w[list view create update delete].map do |action|
            Permission.find_or_create_by!(code: "roles.#{action}") do |permission|
              permission.name = "Roles - #{action.capitalize}"
              permission.platform_scope = Permission::DOFI_OFFICER_PLATFORM
            end
          end
          @admin_role = create(:role, kind: Role::DOFI_OFFICER, permissions: role_permissions)
          @no_access_role = create(:role)

          @admin = create(:user, role: @admin_role, position: "Administrator", unit: "HQ",
                                 password: @password, password_confirmation: @password)
          @plain_user = create(:user, role: @no_access_role, password: @password, password_confirmation: @password)
          @target = create(:role, permissions: [@view_permission])

          @admin_headers = auth_headers_for(@admin, password: @password)
          @plain_headers = auth_headers_for(@plain_user, password: @password)
        end

        test "index requires the list/view permission" do
          get "/api/v1/admin/roles", headers: @plain_headers

          assert_response :forbidden

          get "/api/v1/admin/roles", headers: @admin_headers

          assert_response :ok
        end

        test "index filters by name via ransack" do
          create(:role, name: "Filterable Role")

          get "/api/v1/admin/roles", params: { q: { name_cont: "Filterable" } }, headers: @admin_headers

          assert_response :ok
          assert_equal ["Filterable Role"], response.parsed_body["data"].pluck("name")
        end

        test "index sorts by name descending via ransack" do
          create(:role, name: "Aardvark Role")
          create(:role, name: "Zebra Role")

          get "/api/v1/admin/roles", params: { q: { s: "name desc" } }, headers: @admin_headers

          assert_response :ok
          names = response.parsed_body["data"].pluck("name")

          assert_equal names.sort.reverse, names
        end

        test "show includes assigned permissions" do
          get "/api/v1/admin/roles/#{@target.id}", headers: @admin_headers

          assert_response :ok
          codes = response.parsed_body.dig("data", "permissions").pluck("code")

          assert_includes codes, @view_permission.code
        end

        test "create persists a role with permission assignment" do
          assert_difference("Role.count", 1) do
            post "/api/v1/admin/roles", params: { role: { name: "New Role" },
                                                  permission_codes: [@view_permission.code] },
                                        headers: @admin_headers, as: :json
          end

          assert_response :created
          codes = response.parsed_body.dig("data", "permissions").pluck("code")

          assert_includes codes, @view_permission.code
        end

        test "create without permission is forbidden" do
          post "/api/v1/admin/roles", params: { role: { name: "Blocked Role" } },
                                      headers: @plain_headers, as: :json

          assert_response :forbidden
        end

        test "create rejects a permission code belonging to the fisherman platform" do
          fisherman_only = create(:permission, code: "fisherman_users.create",
                                               platform_scope: Permission::FISHERMAN_PLATFORM)

          assert_no_difference("Role.count") do
            post "/api/v1/admin/roles", params: { role: { name: "Sneaky Role" },
                                                  permission_codes: [fisherman_only.code] },
                                        headers: @admin_headers, as: :json
          end

          assert_response :unprocessable_content
          assert_includes response.parsed_body["errors"].join, "not available to the dofi_officer platform"
        end

        test "created roles are always dofi_officer platform, never client-settable, even when actively sent" do
          foreign_company = create(:company_profile)

          post "/api/v1/admin/roles",
               params: { role: { name: "New Role", platform_scope: "fisherman",
                                 company_profile_id: foreign_company.id } },
               headers: @admin_headers, as: :json

          assert_response :created
          assert_equal ["dofi_officer", nil],
                       response.parsed_body["data"].values_at("platform_scope", "company_profile_id")
        end

        test "update replaces the permission set" do
          another_permission = create(:permission)

          patch "/api/v1/admin/roles/#{@target.id}", params: { role: { name: "Renamed" },
                                                               permission_codes: [another_permission.code] },
                                                     headers: @admin_headers, as: :json

          assert_response :ok
          codes = response.parsed_body.dig("data", "permissions").pluck("code")

          assert_equal [another_permission.code], codes
        end

        test "destroy removes the role and nullifies user role references" do
          user_with_role = create(:user, role: @target)

          delete "/api/v1/admin/roles/#{@target.id}", headers: @admin_headers

          assert_response :ok
          assert_nil user_with_role.reload.role_id
        end
      end
    end
  end
end
