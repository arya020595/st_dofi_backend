require "test_helper"

module Api
  module V1
    module Fisherman
      class FishingGearsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          permissions = %w[manifest_form.create].map do |code|
            Permission.find_or_create_by!(code: code) { |permission| permission.name = code }
          end
          @role = create(:role, permissions: permissions)
          @company_profile = create(:company_profile)
          @vessel = create(:companies_vessel, :approved, company_profile: @company_profile)
          @other_vessel = create(:companies_vessel, :approved, company_profile: @company_profile)
          @user = create(:user, role: @role, company_profile: @company_profile,
                                password: @password, password_confirmation: @password)

          @approved_gear = create(
            :companies_fishing_gear,
            :approved,
            company_profile: @company_profile,
            companies_vessel: @vessel
          )
          create(:companies_fishing_gear, company_profile: @company_profile, companies_vessel: @vessel)
          create(:companies_fishing_gear, :approved, company_profile: @company_profile,
                                                  companies_vessel: @other_vessel)
          create(:companies_fishing_gear, :approved)

          @headers = auth_headers_for(@user, password: @password)
        end

        test "index returns only approved fishing gears for the logged in profile" do
          get "/api/v1/fisherman/fishing_gears", headers: @headers

          assert_response :ok
          ids = response.parsed_body["data"].pluck("id")

          assert_includes ids, @approved_gear.id
          assert_equal 2, ids.size
        end

        test "index filters by vessel_id" do
          get "/api/v1/fisherman/fishing_gears", params: { vessel_id: @vessel.id }, headers: @headers

          assert_response :ok
          assert_equal [@approved_gear.id], response.parsed_body["data"].pluck("id")
        end
      end
    end
  end
end
