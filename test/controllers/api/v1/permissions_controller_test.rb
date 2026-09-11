require "test_helper"

module Api
  module V1
    class PermissionsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @password = "Password123!"
        @shared_permission = create_permission("dashboard.list")
        @list_permission = create_permission("permissions.list")
        @role = create(:role, permissions: [@shared_permission, @list_permission])
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

      test "index returns a flat array with resource/section grouping metadata per permission" do
        get "/api/v1/permissions", headers: @headers

        assert_response :ok
        data = response.parsed_body["data"]

        assert_kind_of Array, data

        shared = data.find { |permission| permission["code"] == @shared_permission.code }

        assert_equal(
          { "action" => "list", "action_order" => 1, "resource" => "dashboard", "section" => "dashboard",
            "section_order" => 1, "resource_order" => 1, "resource_label" => "Dashboard",
            "section_label" => "Dashboard" },
          shared.slice("action", "action_order", "resource", "section", "section_order", "resource_order",
                       "resource_label", "section_label")
        )
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
        create(:permission, code: "manifest.view")

        get "/api/v1/permissions", params: { q: { code_eq: "manifest.view" } }, headers: @headers

        assert_response :ok
        codes = response.parsed_body["data"].pluck("code")

        assert_empty codes
      end

      test "fisherman index exposes every canonical fisherman and shared permission" do
        get "/api/v1/permissions", headers: fisherman_headers_for_permissions_test

        assert_response :ok
        codes = response.parsed_body["data"].pluck("code")

        assert_empty %w[manifests.create ports.view capture_reports.create company_profiles.update] - codes
        assert_not_includes codes, "roles.create"
      end

      private

      def fisherman_headers_for_permissions_test
        build_fisherman_permission_fixtures
        fisherman_role = create(:role, :fisherman, permissions: fisherman_permission_set + [@list_permission])
        fisherman = create(:user, role: fisherman_role, ic_number: "01-880001", registration_type: "Commercial",
                                  password: @password, password_confirmation: @password)

        auth_headers_for(fisherman, password: @password)
      end

      def build_fisherman_permission_fixtures
        @manifest_view = create_permission("manifests.view")
        @manifest_create = create_permission("manifests.create")
        @port_view = create_permission("ports.view")
        @capture_report_create = create_permission("capture_reports.create")
        @company_profile_update = create_permission("company_profiles.update")
        @officer_role_create = create_permission("roles.create")
        @list_permission = create_permission("permissions.list")
      end

      def create_permission(code)
        entry = Permission::Catalog.fetch(code)
        Permission.find_or_create_by!(code:) do |permission|
          permission.name = entry.fetch(:name)
          permission.platform_scope = entry.fetch(:platform_scope)
        end
      end

      def fisherman_permission_set
        [
          @manifest_view, @manifest_create, @port_view, @capture_report_create,
          @company_profile_update
        ]
      end
    end
  end
end
