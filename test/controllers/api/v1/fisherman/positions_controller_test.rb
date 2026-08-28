require "test_helper"

module Api
  module V1
    module Fisherman
      class PositionsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @manifest = create(:manifest)
          @headers = fisherman_headers_for(@manifest, permission_codes: %w[manifest_list.view manifest_form.view])
          @position = create(:position)
        end

        test "index lists positions" do
          get "/api/v1/fisherman/master_data/positions", headers: @headers

          assert_response :ok
          assert_includes response.parsed_body["data"].pluck("id"), @position.id
        end

        test "show returns the position" do
          get "/api/v1/fisherman/master_data/positions/#{@position.id}", headers: @headers

          assert_response :ok
          assert_equal @position.name, response.parsed_body["data"]["name"]
        end

        test "index defaults to name ascending" do
          create(:position, name: "Zulu Position")
          create(:position, name: "Alpha Position")

          get "/api/v1/fisherman/master_data/positions", headers: @headers

          assert_response :ok
          names = response.parsed_body["data"].pluck("name")

          assert_equal names.sort, names
        end
      end
    end
  end
end
