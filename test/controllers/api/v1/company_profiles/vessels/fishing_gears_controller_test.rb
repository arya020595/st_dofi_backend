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
            @admin_role = create(:role, kind: Role::DOFI_OFFICER, permissions: admin_permissions)
            @no_access_role = create(:role, kind: Role::JETTY_MANAGER)

            @admin = create(:user, :officer_shaped, role: @admin_role,
                                                    password: @password, password_confirmation: @password)
            @company_profile = create(:company_profile)
            @plain_user = create(:user, :jetty_manager_shaped, role: @no_access_role,
                                                               company_profile: @company_profile,
                                                               password: @password, password_confirmation: @password)
            @vessel = create(:companies_vessel, company_profile: @company_profile)
            @fishing_gear = create(:fishing_gear)

            @admin_headers = auth_headers_for(@admin, password: @password)
            @plain_headers = auth_headers_for(@plain_user, password: @password)
          end

          test "index requires the list/view permission" do
            path = "/api/v1/admin/company_profiles/#{@company_profile.id}/vessels/#{@vessel.id}/fishing_gears"

            get path, headers: @plain_headers

            assert_response :forbidden

            get path, headers: @admin_headers

            assert_response :ok
          end

          test "create links the vessel to a master fishing gear, pending approval" do
            @vessel.approve!
            params = { fishing_gear: { fishing_gear_id: @fishing_gear.id, local_name: "Pukat Tarik", quantity: 3,
                                       usage_value: 50 } }

            assert_difference("CompaniesFishingGear.count", 1) do
              post "/api/v1/admin/company_profiles/#{@company_profile.id}/vessels/#{@vessel.id}/fishing_gears",
                   params: params, headers: @admin_headers, as: :json
            end

            assert_response :created
            assert_created_fishing_gear_response
          end

          test "update reverts the vessel approval back to pending" do
            @vessel.approve!
            gear = create(:companies_fishing_gear, :approved,
                          company_profile: @company_profile,
                          companies_vessel: @vessel)

            patch fishing_gear_path(gear),
                  params: { fishing_gear: { quantity: 7 } }, headers: @admin_headers, as: :json

            assert_response :ok
            assert_equal "pending", @vessel.reload.approval_status
          end

          test "update re-snapshots fishing gear details when fishing_gear_id changes" do
            @vessel.approve!
            gear = create(:companies_fishing_gear, :approved,
                          company_profile: @company_profile,
                          companies_vessel: @vessel)
            new_fishing_gear = create(:fishing_gear, name: "Trawl Net", gear_type: "Net", fee: 25.0)

            patch fishing_gear_path(gear),
                  params: { fishing_gear: { fishing_gear_id: new_fishing_gear.id } },
                  headers: @admin_headers, as: :json

            assert_response :ok
            data = response.parsed_body["data"]

            assert_equal [new_fishing_gear.id, "Trawl Net", "Net", "25.0"],
                         data.values_at("fishing_gear_id", "fishing_gear_name", "fishing_gear_type",
                                        "fishing_gear_fee")
          end

          test "destroy soft-deletes the vessel's fishing gear link" do
            @vessel.approve!
            gear = create(:companies_fishing_gear, company_profile: @company_profile, companies_vessel: @vessel)

            delete "/api/v1/admin/company_profiles/#{@company_profile.id}/vessels/#{@vessel.id}" \
                   "/fishing_gears/#{gear.id}", headers: @admin_headers

            assert_response :ok
            assert_predicate gear.reload, :discarded?
            assert_equal "pending", @vessel.reload.approval_status
          end

          private

          def assert_created_fishing_gear_response
            data = response.parsed_body["data"]

            assert_equal ["pending", @fishing_gear.id, @vessel.id],
                         [data["approval_status"], data["fishing_gear_id"], data["companies_vessel_id"]]

            assert_equal "pending", @vessel.reload.approval_status
          end

          def fishing_gear_path(gear)
            "/api/v1/admin/company_profiles/#{@company_profile.id}/vessels/#{@vessel.id}/fishing_gears/#{gear.id}"
          end
        end
      end
    end
  end
end
