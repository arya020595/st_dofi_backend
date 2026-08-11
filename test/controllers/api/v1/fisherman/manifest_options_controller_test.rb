require "test_helper"

module Api
  module V1
    module Fisherman
      class ManifestOptionsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"
          permission = Permission.find_or_create_by!(code: "manifest_form.create") do |record|
            record.name = "Manifest form - Create"
          end
          @no_access_role = create(:role)
          @company_profile = create(:company_profile)
          @fisherman_role = create(:role, :fisherman, name: "Fisherman", company_profile: @company_profile,
                                                      permissions: [permission])
          @fisherman = create(:user, role: @fisherman_role, company_profile: @company_profile,
                                     ic_number: "01-800100", registration_type: "Commercial",
                                     password: @password, password_confirmation: @password)
          @plain_user = create(:user, role: @no_access_role, password: @password, password_confirmation: @password)
          @fisherman_headers = auth_headers_for(@fisherman, password: @password)
          @plain_headers = auth_headers_for(@plain_user, password: @password)
        end

        {
          vessels: [CompaniesVessel, :companies_vessel, "vessel_name"],
          crews: [CompaniesCrew, :companies_crew, "crew_name"]
        }.each do |endpoint, (_model, factory, name_field)|
          test "#{endpoint} require manifest create permission and return only this company's approved records" do
            approved = create(factory, :approved, company_profile: @company_profile)
            create(factory, company_profile: @company_profile)
            create(factory, :approved)

            get "/api/v1/fisherman/#{endpoint}", headers: @plain_headers

            assert_response :forbidden

            get "/api/v1/fisherman/#{endpoint}", headers: @fisherman_headers

            assert_response :ok

            data = response.parsed_body.fetch("data")

            assert_equal [approved.public_send(name_field)], data.pluck(name_field)
          end
        end

        # Captains aren't their own resource — they're CompaniesCrew rows filtered to the
        # "Boat Captain" position, so this can't share the generic loop above (it also needs to
        # exclude approved crew in the right company with the wrong position).
        test "captains require manifest create permission and return only this company's approved Boat Captain crew" do
          boat_captain = create(:position, name: "Boat Captain")
          approved = create(:companies_crew, :approved, company_profile: @company_profile, position: boat_captain)
          create(:companies_crew, company_profile: @company_profile, position: boat_captain)
          create(:companies_crew, :approved, company_profile: @company_profile)
          create(:companies_crew, :approved, position: boat_captain)

          get "/api/v1/fisherman/captains", headers: @plain_headers

          assert_response :forbidden

          get "/api/v1/fisherman/captains", headers: @fisherman_headers

          assert_response :ok

          data = response.parsed_body.fetch("data")

          assert_equal [approved.crew_name], data.pluck("crew_name")
        end
      end
    end
  end
end
