require "test_helper"

module Api
  module V1
    module Fisherman
      class ZonesControllerTest < ActionDispatch::IntegrationTest
        setup do
          @manifest = create(:manifest)
          @headers = fisherman_headers_for(@manifest, permission_codes: %w[zones.view zones.list])
          @zone = create(:zone)
        end

        test "index lists zones" do
          get "/api/v1/fisherman/master_data/zones", headers: @headers

          assert_response :ok
          assert_includes response.parsed_body["data"].pluck("id"), @zone.id
        end

        test "show returns the zone" do
          get "/api/v1/fisherman/master_data/zones/#{@zone.id}", headers: @headers

          assert_response :ok
          assert_equal @zone.name, response.parsed_body["data"]["name"]
        end

        test "index defaults to name ascending" do
          create(:zone, name: "Zeta Zone")
          create(:zone, name: "Alpha Zone")

          get "/api/v1/fisherman/master_data/zones", headers: @headers

          assert_response :ok
          names = response.parsed_body["data"].pluck("name")

          assert_equal names.sort, names
        end
      end
    end
  end
end
