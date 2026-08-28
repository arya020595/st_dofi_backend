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

      test "fisherman index exposes simplified permissions only" do
        get "/api/v1/permissions", headers: fisherman_headers_for_permissions_test

        assert_response :ok
        assert_simplified_fisherman_permission_codes(response.parsed_body["data"].pluck("code"))
      end

      private

      def fisherman_headers_for_permissions_test
        build_fisherman_permission_fixtures
        fisherman_role = create(:role, :fisherman, permissions: fisherman_permission_set)
        fisherman = create(:user, role: fisherman_role, ic_number: "01-880001", registration_type: "Commercial",
                                  password: @password, password_confirmation: @password)

        auth_headers_for(fisherman, password: @password)
      end

      def build_fisherman_permission_fixtures
        @manifest_view = create_permission("manifest.view", Permission::FISHERMAN_PLATFORM)
        @manifest_create = create_permission("manifest.create", Permission::FISHERMAN_PLATFORM)
        @hidden_port = create_permission("ports.view", Permission::SHARED_PLATFORM)
        @hidden_capture_report = create_permission("capture_reports.create", Permission::SHARED_PLATFORM)
        @hidden_manifest_list = create_permission("manifest_list.view", Permission::SHARED_PLATFORM)
        @hidden_manifest_form = create_permission("manifest_form.create", Permission::SHARED_PLATFORM)
        @hidden_profiling_update = create_permission("profiling.update", Permission::SHARED_PLATFORM)
      end

      def create_permission(code, platform_scope)
        create(:permission, code:, platform_scope:)
      end

      def fisherman_permission_set
        [
          @manifest_view, @manifest_create, @hidden_port, @hidden_capture_report,
          @hidden_manifest_list, @hidden_manifest_form, @hidden_profiling_update
        ]
      end

      def assert_simplified_fisherman_permission_codes(codes)
        assert_includes codes, @manifest_view.code
        assert_includes codes, @manifest_create.code
        assert_not_includes codes, @hidden_port.code
        assert_not_includes codes, @hidden_capture_report.code
        assert_not_includes codes, @hidden_manifest_list.code
        assert_not_includes codes, @hidden_manifest_form.code
        assert_not_includes codes, @hidden_profiling_update.code
      end
    end
  end
end
