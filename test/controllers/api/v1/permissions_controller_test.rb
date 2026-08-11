require "test_helper"

module Api
  module V1
    class PermissionsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @password = "Password123!"
        @shared_permission = Permission.find_or_create_by!(code: "dashboard.view") do |permission|
          permission.name = "Dashboard - View"
          permission.platform_scope = Permission::SHARED_PLATFORM
        end
        @role = create(:role, permissions: [@shared_permission])
        @user = create(:user, role: @role, password: @password, password_confirmation: @password)
        @headers = auth_headers_for(@user, password: @password)
      end

      test "index requires authentication" do
        get "/api/v1/permissions"

        assert_response :unauthorized
      end

      test "index lists shared and same-platform permissions" do
        get "/api/v1/permissions", headers: @headers

        assert_response :ok
        codes = response.parsed_body["data"].pluck("code")

        assert_includes codes, @shared_permission.code
      end

      test "index excludes permissions belonging to another platform" do
        fisherman_only = create(:permission, code: "fisherman_users.create",
                                             platform_scope: Permission::FISHERMAN_PLATFORM)

        get "/api/v1/permissions", headers: @headers

        assert_response :ok
        codes = response.parsed_body["data"].pluck("code")

        assert_not_includes codes, fisherman_only.code
      end

      test "index filters by code via ransack" do
        other = create(:permission, code: "reports.export")

        get "/api/v1/permissions", params: { q: { code_cont: "export" } }, headers: @headers

        assert_response :ok
        codes = response.parsed_body["data"].pluck("code")

        assert_equal [other.code], codes
      end
    end
  end
end
