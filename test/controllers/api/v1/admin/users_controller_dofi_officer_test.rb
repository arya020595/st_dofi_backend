require "test_helper"

module Api
  module V1
    module Admin
      class UsersControllerDofiOfficerTest < ActionDispatch::IntegrationTest
        setup do
          password = "Password123!"
          admin_permissions = %w[list view create update delete].map do |action|
            Permission.find_or_create_by!(code: "users.#{action}") do |permission|
              permission.name = "Dofi officer users - #{action.capitalize}"
            end
          end
          admin_role = create(:role, kind: Role::DOFI_OFFICER, permissions: admin_permissions)
          admin = create(:user, role: admin_role, position: "Administrator", unit: "HQ",
                                password: password, password_confirmation: password)
          @admin_headers = auth_headers_for(admin, password: password)
          # DOFI_OFFICER is a singleton kind (unique index) — reuse the same role admin already
          # holds rather than creating a second row, which the app's own domain model forbids.
          @officer_role = admin_role
        end

        test "create for the DoFi Officer role needs no email/password" do
          post "/api/v1/admin/users", params: { user: { name: "Azri Bin Haji Nizam Matussin", position: "Administrator",
                                                        unit: "Block A", username: "mprt/azri.nizam",
                                                        role_id: @officer_role.id } },
                                      headers: @admin_headers, as: :json

          assert_response :created
        end

        test "create for the DoFi Officer role issues no password" do
          post "/api/v1/admin/users", params: { user: { name: "Azri Bin Haji Nizam Matussin", position: "Administrator",
                                                        unit: "Block A", username: "mprt/azri.nizam",
                                                        role_id: @officer_role.id } },
                                      headers: @admin_headers, as: :json

          assert_response :created
          assert_nil response.parsed_body.dig("data", "temporary_password")
        end

        test "create for the DoFi Officer role requires position, unit, and username" do
          post "/api/v1/admin/users", params: { user: { name: "No Fields", role_id: @officer_role.id } },
                                      headers: @admin_headers, as: :json

          assert_response :unprocessable_content
          assert_predicate response.parsed_body["errors"], :present?
        end

        test "a created officer is never given the mock directory password or any other usable password" do
          post "/api/v1/admin/users", params: { user: { name: "Azri Bin Haji Nizam Matussin", position: "Administrator",
                                                        unit: "Block A", username: "mprt/azri.nizam",
                                                        role_id: @officer_role.id } },
                                      headers: @admin_headers, as: :json
          created = User.find(response.parsed_body.dig("data", "id"))

          assert_not BCrypt::Password.new(created.encrypted_password).is_password?(DirectoryTestSupport::MOCK_PASSWORD)
          assert_not created.valid_password?(DirectoryTestSupport::MOCK_PASSWORD)
        end

        test "changing an officer's username revokes their token, a profile edit does not" do
          officer = create(:user, :officer_shaped, role: @officer_role, username: "mprt/existing")
          officer_headers = auth_headers_for(officer, password: "unused")

          patch "/api/v1/admin/users/#{officer.id}", params: { user: { name: "Renamed", unit: "Block C" } },
                                                     headers: @admin_headers, as: :json
          get "/api/v1/auth/me", headers: officer_headers

          assert_response :ok

          patch "/api/v1/admin/users/#{officer.id}", params: { user: { username: "mprt/renamed.officer" } },
                                                     headers: @admin_headers, as: :json
          get "/api/v1/auth/me", headers: officer_headers

          assert_response :unauthorized
          get "/api/v1/auth/me", headers: @admin_headers

          assert_response :ok
        end

        test "deactivating an officer in the admin API locks out their token; re-enabling does not restore it" do
          officer = create(:user, :officer_shaped, role: @officer_role, username: "mprt/existing")
          officer_headers = auth_headers_for(officer, password: "unused")

          patch "/api/v1/admin/users/#{officer.id}", params: { user: { status: "inactive" } },
                                                     headers: @admin_headers, as: :json
          get "/api/v1/auth/me", headers: officer_headers

          assert_response :unauthorized

          patch "/api/v1/admin/users/#{officer.id}", params: { user: { status: "active" } },
                                                     headers: @admin_headers, as: :json
          get "/api/v1/auth/me", headers: officer_headers

          assert_response :unauthorized
          get "/api/v1/auth/me", headers: auth_headers_for(officer, password: "unused")

          assert_response :ok
        end

        test "create ignores a supplied password: staff sign in through Active Directory, not a local password" do
          post "/api/v1/admin/users", params: { user: { name: "Azri Bin Haji Nizam Matussin", position: "Administrator",
                                                        unit: "Block A", username: "mprt/azri.nizam",
                                                        role_id: @officer_role.id, password: "AdminChosen1!",
                                                        password_confirmation: "AdminChosen1!" } },
                                      headers: @admin_headers, as: :json

          assert_response :created
          assert_not User.last.valid_password?("AdminChosen1!")
        end

        test "update ignores a supplied password" do
          officer = create(:user, role: @officer_role, position: "Administrator", unit: "Block A",
                                  username: "mprt/existing")

          patch "/api/v1/admin/users/#{officer.id}",
                params: { user: { name: "Renamed Officer", password: "NewPassword1!",
                                  password_confirmation: "NewPassword1!" } },
                headers: @admin_headers, as: :json

          assert_response :success
          assert_equal "Renamed Officer", officer.reload.name
          assert_not officer.valid_password?("NewPassword1!")
        end
      end
    end
  end
end
