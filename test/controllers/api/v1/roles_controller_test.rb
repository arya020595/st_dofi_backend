require "test_helper"

module Api
  module V1
    class RolesControllerTest < ActionDispatch::IntegrationTest
      setup do
        @password = "Password123!"

        @view_permission = create(:permission, code: "manifest_list.view")
        role_permissions = %w[list view create update delete].map do |action|
          create(:permission, code: "roles.#{action}")
        end
        @admin_role = create(:role, permissions: role_permissions)
        @no_access_role = create(:role)

        @admin = create(:user, role: @admin_role, password: @password, password_confirmation: @password)
        @plain_user = create(:user, role: @no_access_role, password: @password, password_confirmation: @password)
        @target = create(:role, permissions: [@view_permission])

        @admin_headers = auth_headers_for(@admin, password: @password)
        @plain_headers = auth_headers_for(@plain_user, password: @password)
      end

      test "index requires the list/view permission" do
        get "/api/v1/roles", headers: @plain_headers

        assert_response :forbidden

        get "/api/v1/roles", headers: @admin_headers

        assert_response :ok
      end

      test "index filters by name via ransack" do
        create(:role, reference_id: "ROLE-FILTER", name: "Filterable Role")

        get "/api/v1/roles", params: { q: { name_cont: "Filterable" } }, headers: @admin_headers

        assert_response :ok
        assert_equal ["Filterable Role"], response.parsed_body["data"].pluck("name")
      end

      test "index sorts by name descending via ransack" do
        create(:role, reference_id: "ROLE-A", name: "Aardvark Role")
        create(:role, reference_id: "ROLE-Z", name: "Zebra Role")

        get "/api/v1/roles", params: { q: { s: "name desc" } }, headers: @admin_headers

        assert_response :ok
        names = response.parsed_body["data"].pluck("name")

        assert_equal names.sort.reverse, names
      end

      test "show includes assigned permissions" do
        get "/api/v1/roles/#{@target.id}", headers: @admin_headers

        assert_response :ok
        codes = response.parsed_body.dig("data", "permissions").pluck("code")

        assert_includes codes, @view_permission.code
      end

      test "create persists a role with permission assignment" do
        assert_difference("Role.count", 1) do
          post "/api/v1/roles", params: { role: { reference_id: "ROLE-NEW", name: "New Role" },
                                          permission_codes: [@view_permission.code] },
                                headers: @admin_headers, as: :json
        end

        assert_response :created
        codes = response.parsed_body.dig("data", "permissions").pluck("code")

        assert_includes codes, @view_permission.code
      end

      test "create without permission is forbidden" do
        post "/api/v1/roles", params: { role: { reference_id: "ROLE-X", name: "Blocked Role" } },
                              headers: @plain_headers, as: :json

        assert_response :forbidden
      end

      test "update replaces the permission set" do
        another_permission = create(:permission, code: "dictionaries.view")

        patch "/api/v1/roles/#{@target.id}", params: { role: { name: "Renamed" },
                                                       permission_codes: [another_permission.code] },
                                             headers: @admin_headers, as: :json

        assert_response :ok
        codes = response.parsed_body.dig("data", "permissions").pluck("code")

        assert_equal [another_permission.code], codes
      end

      test "destroy removes the role and nullifies user role references" do
        user_with_role = create(:user, role: @target)

        delete "/api/v1/roles/#{@target.id}", headers: @admin_headers

        assert_response :ok
        assert_nil user_with_role.reload.role_id
      end
    end
  end
end
