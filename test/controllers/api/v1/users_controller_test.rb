require "test_helper"

module Api
  module V1
    class UsersControllerTest < ActionDispatch::IntegrationTest
      setup do
        @password = "Password123!"

        admin_permissions = %w[list view create update delete].map do |action|
          Permission.find_or_create_by!(code: "dofi_officer_users.#{action}") do |permission|
            permission.name = "Dofi officer users - #{action.capitalize}"
          end
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

      test "create assigns the admin-supplied role_id and auto-generates employee_id" do
        post "/api/v1/users", params: { user: { name: "New Officer", email: "officer2@example.com",
                                                password: @password, password_confirmation: @password,
                                                role_id: @no_access_role.id, employee_id: "SNEAKY-001" } },
                              headers: @admin_headers, as: :json

        assert_response :created
        user = User.last

        assert_equal @no_access_role.id, user.role_id
        assert_match(/\ADOF-\d{3}\z/, user.employee_id)
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

      test "create for the DoFi Officer role needs no email/password and returns a one-time password" do
        officer_role = create(:role, reference_id: User::DOFI_OFFICER_ROLE_REFERENCE_ID)

        assert_difference("User.count", 1) do
          post "/api/v1/users", params: { user: { name: "Azri Bin Haji Nizam Matussin", position: "Administrator",
                                                  unit: "Block A", username: "mprt/azri.nizam",
                                                  role_id: officer_role.id } },
                                headers: @admin_headers, as: :json
        end

        assert_response :created
        temporary_password = response.parsed_body.dig("data", "temporary_password")
        assert_predicate temporary_password, :present?
        assert User.last.valid_password?(temporary_password)
      end

      test "create for the DoFi Officer role requires position, unit, and username" do
        officer_role = create(:role, reference_id: User::DOFI_OFFICER_ROLE_REFERENCE_ID)

        post "/api/v1/users", params: { user: { name: "No Fields", role_id: officer_role.id } },
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
