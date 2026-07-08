require "test_helper"

module Api
  module V1
    class UsersControllerDofiOfficerTest < ActionDispatch::IntegrationTest
      setup do
        password = "Password123!"
        admin_permissions = %w[list view create update delete].map do |action|
          Permission.find_or_create_by!(code: "dofi_officer_users.#{action}") do |permission|
            permission.name = "Dofi officer users - #{action.capitalize}"
          end
        end
        admin_role = create(:role, permissions: admin_permissions)
        admin = create(:user, role: admin_role, password: password, password_confirmation: password)
        @admin_headers = auth_headers_for(admin, password: password)
        @officer_role = create(:role, reference_id: User::DOFI_OFFICER_ROLE_REFERENCE_ID)
      end

      test "create for the DoFi Officer role needs no email/password" do
        post "/api/v1/users", params: { user: { name: "Azri Bin Haji Nizam Matussin", position: "Administrator",
                                                unit: "Block A", username: "mprt/azri.nizam",
                                                role_id: @officer_role.id } },
                              headers: @admin_headers, as: :json

        assert_response :created
      end

      test "create for the DoFi Officer role returns a working one-time temporary_password" do
        post "/api/v1/users", params: { user: { name: "Azri Bin Haji Nizam Matussin", position: "Administrator",
                                                unit: "Block A", username: "mprt/azri.nizam",
                                                role_id: @officer_role.id } },
                              headers: @admin_headers, as: :json

        temporary_password = response.parsed_body.dig("data", "temporary_password")

        assert_predicate temporary_password, :present?
        assert User.last.valid_password?(temporary_password)
      end

      test "create for the DoFi Officer role requires position, unit, and username" do
        post "/api/v1/users", params: { user: { name: "No Fields", role_id: @officer_role.id } },
                              headers: @admin_headers, as: :json

        assert_response :unprocessable_content
        assert_predicate response.parsed_body["errors"], :present?
      end
    end
  end
end
