require "test_helper"

module Api
  module V1
    module Admin
      class FishingGearsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @headers = officer_headers_for(permission_codes: %w[fishing_gears.view fishing_gears.list
                                                              fishing_gears.create fishing_gears.update
                                                              fishing_gears.delete])
          @gear = create(:fishing_gear)
        end

        test "index lists fishing gears" do
          get "/api/v1/admin/master_data/fishing_gears", headers: @headers
          get "/api/v1/admin/master_data/fishing_gears", headers: @headers

          assert_response :ok
          assert_includes response.parsed_body["data"].pluck("id"), @gear.id
        end

        test "show returns the fishing gear" do
          get "/api/v1/admin/master_data/fishing_gears/#{@gear.id}", headers: @headers
          get "/api/v1/admin/master_data/fishing_gears/#{@gear.id}", headers: @headers

          assert_response :ok
          assert_equal @gear.name, response.parsed_body["data"]["name"]
        end

        test "create persists a fishing gear" do
          assert_difference("FishingGear.count", 1) do
            post "/api/v1/admin/master_data/fishing_gears",
                 params: { fishing_gear: { local_name: "Pukat Baru", name: "New Gear", gear_type: "Net", fee: 15.0 } },
                 headers: @headers, as: :json
          end

          assert_response :created
        end

        test "update modifies the fishing gear" do
          patch "/api/v1/admin/master_data/fishing_gears/#{@gear.id}",
                params: { fishing_gear: { name: "Renamed Gear" } },
                headers: @headers, as: :json

          assert_response :ok
          assert_equal "Renamed Gear", @gear.reload.name
        end

        test "destroy removes the fishing gear" do
          delete "/api/v1/admin/master_data/fishing_gears/#{@gear.id}", headers: @headers
          delete "/api/v1/admin/master_data/fishing_gears/#{@gear.id}", headers: @headers

          assert_response :ok
          assert_not FishingGear.exists?(@gear.id)
        end
      end
    end
  end
end
