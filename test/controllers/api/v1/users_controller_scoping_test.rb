require "test_helper"

module Api
  module V1
    class UsersControllerScopingTest < ActionDispatch::IntegrationTest
      setup do
        @password = "Password123!"

        admin_permissions = %w[list view].map do |action|
          Permission.find_or_create_by!(code: "dofi_officer_users.#{action}") do |permission|
            permission.name = "Dofi officer users - #{action.capitalize}"
          end
        end
        @admin_role = create(:role, permissions: admin_permissions)
        @admin = create(:user, role: @admin_role, password: @password, password_confirmation: @password)
        @admin_headers = auth_headers_for(@admin, password: @password)
      end

      test "index excludes fisherman and jetty manager role users" do
        fisherman_role = create(:role, kind: Role::FISHERMAN, name: "Fisherman")
        jetty_manager_role = create(:role, kind: Role::JETTY_MANAGER, name: "Jetty Manager")
        fisherman = create(:user, role: fisherman_role, ic_number: "01-820001",
                                  registration_type: "Small - Scale (Full-Time)")
        jetty_manager = create(:user, role: jetty_manager_role, ic_number: "01-820002", unit: "Docks",
                                      position: "Supervisor", contact_no: "71111111")

        get "/api/v1/users", headers: @admin_headers
        ids = response.parsed_body["data"].pluck("id")

        assert_not_includes ids, fisherman.id
        assert_not_includes ids, jetty_manager.id
      end

      test "a fisherman id 404s against the show/update/destroy actions" do
        fisherman_role = create(:role, kind: Role::FISHERMAN, name: "Fisherman")
        fisherman = create(:user, role: fisherman_role, ic_number: "01-820003",
                                  registration_type: "Small - Scale (Full-Time)")

        get "/api/v1/users/#{fisherman.id}", headers: @admin_headers

        assert_response :not_found
      end
    end
  end
end
