require "test_helper"

module Api
  module V1
    module Admin
      class UsersControllerDofiOfficerTest < ActionDispatch::IntegrationTest
        setup do
          password = "Password123!"
          admin_permissions = %w[list view create update delete].map do |action|
            Permission.find_or_create_by!(code: "dofi_officer_users.#{action}") do |permission|
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

        test "create for the DoFi Officer role returns a working one-time temporary_password" do
          post "/api/v1/admin/users", params: { user: { name: "Azri Bin Haji Nizam Matussin", position: "Administrator",
                                                        unit: "Block A", username: "mprt/azri.nizam",
                                                        role_id: @officer_role.id } },
                                      headers: @admin_headers, as: :json

          temporary_password = response.parsed_body.dig("data", "temporary_password")

          assert_predicate temporary_password, :present?
          assert User.last.valid_password?(temporary_password)
        end

        test "create for the DoFi Officer role requires position, unit, and username" do
          post "/api/v1/admin/users", params: { user: { name: "No Fields", role_id: @officer_role.id } },
                                      headers: @admin_headers, as: :json

          assert_response :unprocessable_content
          assert_predicate response.parsed_body["errors"], :present?
        end

        test "create with an admin-supplied password uses it instead of generating one" do
          post "/api/v1/admin/users", params: { user: { name: "Azri Bin Haji Nizam Matussin", position: "Administrator",
                                                        unit: "Block A", username: "mprt/azri.nizam",
                                                        role_id: @officer_role.id, password: "AdminChosen1!",
                                                        password_confirmation: "AdminChosen1!" } },
                                      headers: @admin_headers, as: :json

          assert_response :created
          assert_nil response.parsed_body.dig("data", "temporary_password")
          assert User.last.valid_password?("AdminChosen1!")
        end

        test "update changes the user's password" do
          officer = create(:user, role: @officer_role, position: "Administrator", unit: "Block A",
                                  username: "mprt/existing")

          patch "/api/v1/admin/users/#{officer.id}",
                params: { user: { password: "NewPassword1!", password_confirmation: "NewPassword1!" } },
                headers: @admin_headers, as: :json

          assert_response :success
          assert officer.reload.valid_password?("NewPassword1!")
        end
      end
    end
  end
end
