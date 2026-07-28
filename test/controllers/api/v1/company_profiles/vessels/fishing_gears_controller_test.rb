require "test_helper"

module Api
  module V1
    module CompanyProfiles
      module Vessels
        class FishingGearsControllerTest < ActionDispatch::IntegrationTest
          setup do
            @password = "Password123!"

            admin_permissions = %w[view list create update delete].map do |action|
              Permission.find_or_create_by!(code: "companies_fishing_gears.#{action}") do |p|
                p.name = "Gears - #{action}"
              end
            end
            @admin_role = create(:role, permissions: admin_permissions)
            @no_access_role = create(:role)

            @admin = create(:user, role: @admin_role, password: @password, password_confirmation: @password)
            @plain_user = create(:user, role: @no_access_role, password: @password, password_confirmation: @password)
            @company_profile = create(:company_profile)
            @vessel = create(:companies_vessel, company_profile: @company_profile)
            @fishing_gear = create(:fishing_gear)

            @admin_headers = auth_headers_for(@admin, password: @password)
            @plain_headers = auth_headers_for(@plain_user, password: @password)
          end

          test "index requires the list/view permission" do
            path = "/api/v1/company_profiles/#{@company_profile.id}/vessels/#{@vessel.id}/fishing_gears"

            get path, headers: @plain_headers

            assert_response :forbidden

            get path, headers: @admin_headers

            assert_response :ok
          end

          test "create links the vessel to a master fishing gear, pending approval" do
            params = { fishing_gear: { fishing_gear_id: @fishing_gear.id, local_name: "Pukat Tarik", quantity: 3,
                                       usage_value: 50 } }

            assert_difference("CompaniesFishingGear.count", 1) do
              post "/api/v1/company_profiles/#{@company_profile.id}/vessels/#{@vessel.id}/fishing_gears",
                   params: params, headers: @admin_headers, as: :json
            end

            assert_response :created
            data = response.parsed_body["data"]

            assert_equal ["pending", @fishing_gear.id, @vessel.id],
                         [data["approval_status"], data["fishing_gear_id"], data["companies_vessel_id"]]
          end

          test "destroy soft-deletes the vessel's fishing gear link" do
            gear = create(:companies_fishing_gear, company_profile: @company_profile, companies_vessel: @vessel)

            delete "/api/v1/company_profiles/#{@company_profile.id}/vessels/#{@vessel.id}/fishing_gears/#{gear.id}",
                   headers: @admin_headers

            assert_response :ok
            assert_predicate gear.reload, :discarded?
          end
        end
      end
    end
  end
end
