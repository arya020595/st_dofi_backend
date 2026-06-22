require "test_helper"

module Api
  module V1
    class PermissionsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @password = "Password123!"
        @permission = create(:permission, code: "dashboard.view")
        @role = create(:role, permissions: [@permission])
        @user = create(:user, role: @role, password: @password, password_confirmation: @password)
        @headers = auth_headers_for(@user, password: @password)
      end

      test "index requires authentication" do
        get "/api/v1/permissions"

        assert_response :unauthorized
      end

      test "index lists permissions for any authenticated user" do
        get "/api/v1/permissions", headers: @headers

        assert_response :ok
        codes = response.parsed_body["data"].pluck("code")

        assert_includes codes, @permission.code
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
