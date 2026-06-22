require "test_helper"

module Api
  module V1
    class UsersControllerTest < ActionDispatch::IntegrationTest
      setup do
        @password = "Password123!"

        admin_permissions = %w[list view create update delete].map do |action|
          create(:permission, code: "dofi_officer_users.#{action}")
        end
        @admin_role = create(:role, permissions: admin_permissions)
        @no_access_role = create(:role)

        @admin = create(:user, role: @admin_role, password: @password, password_confirmation: @password)
        @plain_user = create(:user, role: @no_access_role, password: @password, password_confirmation: @password)
        @target = create(:user, role: @no_access_role)

        @admin_headers = auth_headers_for(@admin, password: @password)
        @plain_headers = auth_headers_for(@plain_user, password: @password)
      end

      test "index requires the list/view permission" do
        get "/api/v1/users", headers: @plain_headers

        assert_response :forbidden

        get "/api/v1/users", headers: @admin_headers

        assert_response :ok
        assert_kind_of Array, response.parsed_body["data"]
      end

      test "index filters by name via ransack" do
        create(:user, role: @no_access_role, name: "Alice Tan", email: "alice@example.com")
        create(:user, role: @no_access_role, name: "Bob Lim", email: "bob@example.com")

        get "/api/v1/users", params: { q: { name_cont: "Alice" } }, headers: @admin_headers

        assert_response :ok
        assert_equal ["Alice Tan"], response.parsed_body["data"].pluck("name")
      end

      test "index sorts by name via ransack" do
        create(:user, role: @no_access_role, name: "Zed", email: "zed@example.com")
        create(:user, role: @no_access_role, name: "Amy", email: "amy@example.com")

        get "/api/v1/users", params: { q: { s: "name asc" } }, headers: @admin_headers

        assert_response :ok
        names = response.parsed_body["data"].pluck("name")

        assert_equal names.sort, names
      end

      test "index ignores non-whitelisted ransack attributes instead of raising" do
        get "/api/v1/users", params: { q: { encrypted_password_cont: "x" } }, headers: @admin_headers

        assert_response :ok
      end

      test "show returns a single user" do
        get "/api/v1/users/#{@target.id}", headers: @admin_headers

        assert_response :ok
        assert_equal @target.email, response.parsed_body.dig("data", "email")
      end

      test "create persists a new user when authorized" do
        assert_difference("User.count", 1) do
          post "/api/v1/users", params: { user: { name: "New Officer", email: "officer@example.com",
                                                  password: @password, password_confirmation: @password,
                                                  role_id: @no_access_role.id } },
                                headers: @admin_headers, as: :json
        end

        assert_response :created
      end

      test "create without permission is forbidden" do
        post "/api/v1/users", params: { user: { name: "x", email: "x@example.com", password: @password,
                                                password_confirmation: @password } },
                              headers: @plain_headers, as: :json

        assert_response :forbidden
      end

      test "create with invalid params returns errors" do
        post "/api/v1/users", params: { user: { name: "", email: "", password: @password,
                                                password_confirmation: @password } },
                              headers: @admin_headers, as: :json

        assert_response :unprocessable_content
        assert_predicate response.parsed_body["errors"], :present?
      end

      test "update modifies the target user" do
        patch "/api/v1/users/#{@target.id}", params: { user: { name: "Updated Name" } },
                                             headers: @admin_headers, as: :json

        assert_response :ok
        assert_equal "Updated Name", @target.reload.name
      end

      test "destroy soft-deletes the target user" do
        delete "/api/v1/users/#{@target.id}", headers: @admin_headers

        assert_response :ok
        assert_predicate @target.reload, :discarded?
      end

      test "discarded users are not returned by show" do
        @target.discard!

        get "/api/v1/users/#{@target.id}", headers: @admin_headers

        assert_response :not_found
      end
    end
  end
end
