require "test_helper"

module Api
  module V1
    module Admin
      module Manifests
        class MinorFishermenControllerTest < ActionDispatch::IntegrationTest
          setup do
            @manifest = create(:manifest, :small_scale)
            @headers = officer_headers_for(permission_codes: %w[manifest_minor_fishermen.view])
          end

          test "index lists minor fishermen for the manifest" do
            create(:manifest_minor_fisherman, manifest: @manifest)

            get "/api/v1/admin/manifests/#{@manifest.id}/minor_fishermen", headers: @headers

            assert_response :ok
            assert_equal 1, response.parsed_body["data"].size
          end
        end
      end
    end
  end
end
