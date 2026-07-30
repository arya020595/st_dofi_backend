require "test_helper"

module Api
  module V1
    module Fisherman
      class FishingGearsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @manifest = create(:manifest)
          @headers = fisherman_headers_for(@manifest, permission_codes: %w[fishing_gears.view fishing_gears.list])
          @gear = create(:fishing_gear)
        end

        test "index lists fishing gears" do
          get "/api/v1/fisherman/fishing_gears", headers: @headers

          assert_response :ok
          assert_includes response.parsed_body["data"].pluck("id"), @gear.id
        end

        test "show returns the fishing gear" do
          get "/api/v1/fisherman/fishing_gears/#{@gear.id}", headers: @headers

          assert_response :ok
          assert_equal @gear.name, response.parsed_body["data"]["name"]
        end
      end
    end
  end
end
