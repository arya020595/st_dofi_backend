require "test_helper"

module Api
  module V1
    module CompanyProfiles
      class VesselsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          admin_permissions = %w[view list create update delete].map do |action|
            Permission.find_or_create_by!(code: "companies_vessels.#{action}") { |p| p.name = "Vessels - #{action}" }
          end
          @admin_role = create(:role, kind: Role::DOFI_OFFICER, permissions: admin_permissions)
          @no_access_role = create(:role)

          @admin = create(:user, role: @admin_role, position: "Administrator", unit: "HQ",
                                 password: @password, password_confirmation: @password)
          @company_profile = create(:company_profile)
          @plain_user = create(:user, role: @no_access_role, company_profile: @company_profile,
                                      password: @password, password_confirmation: @password)

          @admin_headers = auth_headers_for(@admin, password: @password)
          @plain_headers = auth_headers_for(@plain_user, password: @password)
        end

        test "index requires the list/view permission" do
          get "/api/v1/company_profiles/#{@company_profile.id}/vessels", headers: @plain_headers

          assert_response :forbidden

          get "/api/v1/company_profiles/#{@company_profile.id}/vessels", headers: @admin_headers

          assert_response :ok
        end

        test "create adds a pending vessel under the company" do
          params = { vessel: { vessel_name: "Kapal Laut I", boat_number: "BN 9283", capacity: 10 } }

          assert_difference("CompaniesVessel.count", 1) do
            post "/api/v1/company_profiles/#{@company_profile.id}/vessels", params: params,
                                                                            headers: @admin_headers, as: :json
          end

          assert_response :created
          data = response.parsed_body["data"]

          assert_equal "pending", data["approval_status"]
        end

        test "update modifies the vessel" do
          vessel = create(:companies_vessel, company_profile: @company_profile)

          patch "/api/v1/company_profiles/#{@company_profile.id}/vessels/#{vessel.id}",
                params: { vessel: { vessel_name: "Renamed Vessel" } }, headers: @admin_headers, as: :json

          assert_response :ok
          assert_equal "Renamed Vessel", vessel.reload.vessel_name
        end

        test "destroy soft-deletes the vessel" do
          vessel = create(:companies_vessel, company_profile: @company_profile)

          delete "/api/v1/company_profiles/#{@company_profile.id}/vessels/#{vessel.id}", headers: @admin_headers

          assert_response :ok
          assert_predicate vessel.reload, :discarded?
        end
      end
    end
  end
end
