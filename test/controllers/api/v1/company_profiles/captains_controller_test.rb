require "test_helper"

module Api
  module V1
    module CompanyProfiles
      class CaptainsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          admin_permissions = %w[view list create update delete].map do |action|
            Permission.find_or_create_by!(code: "companies_captains.#{action}") { |p| p.name = "Captains - #{action}" }
          end
          @admin_role = create(:role, kind: Role::DOFI_OFFICER, permissions: admin_permissions)
          @no_access_role = create(:role, kind: Role::JETTY_MANAGER)

          @admin = create(:user, :officer_shaped, role: @admin_role,
                                                  password: @password, password_confirmation: @password)
          @company_profile = create(:company_profile)
          @plain_user = create(:user, :jetty_manager_shaped, role: @no_access_role, company_profile: @company_profile,
                                                             password: @password, password_confirmation: @password)

          @admin_headers = auth_headers_for(@admin, password: @password)
          @plain_headers = auth_headers_for(@plain_user, password: @password)
        end

        test "index requires the list/view permission" do
          get "/api/v1/admin/company_profiles/#{@company_profile.id}/captains", headers: @plain_headers

          assert_response :forbidden

          get "/api/v1/admin/company_profiles/#{@company_profile.id}/captains", headers: @admin_headers

          assert_response :ok
        end

        test "create adds a pending captain under the company" do
          params = { captain: { captain_name: "Muhammad Shahrizan", nationality: "Bruneian" } }

          assert_difference("CompaniesCaptain.count", 1) do
            post "/api/v1/admin/company_profiles/#{@company_profile.id}/captains", params: params,
                                                                                   headers: @admin_headers, as: :json
          end

          assert_response :created
          assert_equal "pending", response.parsed_body.dig("data", "approval_status")
        end

        test "destroy soft-deletes the captain" do
          captain = create(:companies_captain, company_profile: @company_profile)

          delete "/api/v1/admin/company_profiles/#{@company_profile.id}/captains/#{captain.id}", headers: @admin_headers

          assert_response :ok
          assert_predicate captain.reload, :discarded?
        end
      end
    end
  end
end
