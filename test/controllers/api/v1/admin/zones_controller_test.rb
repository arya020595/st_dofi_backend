require "test_helper"

module Api
  module V1
    module Admin
      class ZonesControllerTest < ActionDispatch::IntegrationTest
        setup do
          @headers = officer_headers_for(permission_codes: %w[zones.view zones.list zones.create zones.update
                                                              zones.delete])
          @zone = create(:zone)
        end

        test "index lists zones" do
          get "/api/v1/admin/zones", headers: @headers

          assert_response :ok
          assert_includes response.parsed_body["data"].pluck("id"), @zone.id
        end

        test "show returns the zone" do
          get "/api/v1/admin/zones/#{@zone.id}", headers: @headers

          assert_response :ok
          assert_equal @zone.name, response.parsed_body["data"]["name"]
        end

        test "create persists a zone" do
          assert_difference("Zone.count", 1) do
            post "/api/v1/admin/zones", params: { zone: { name: "New Zone", zone_type: "offshore",
                                                          start_range: "0 nm", end_range: "12 nm" } },
                                        headers: @headers, as: :json
          end

          assert_response :created
        end

        test "update modifies the zone" do
          patch "/api/v1/admin/zones/#{@zone.id}", params: { zone: { name: "Renamed Zone" } },
                                                   headers: @headers, as: :json

          assert_response :ok
          assert_equal "Renamed Zone", @zone.reload.name
        end

        test "destroy removes the zone" do
          delete "/api/v1/admin/zones/#{@zone.id}", headers: @headers

          assert_response :ok
          assert_not Zone.exists?(@zone.id)
        end
      end
    end
  end
end
