require "test_helper"

module Api
  module V1
    module Fisherman
      module Manifests
        class MinorFishermenControllerTest < ActionDispatch::IntegrationTest
          setup do
            @manifest = create(:manifest, :small_scale)
            @headers = fisherman_headers_for(@manifest,
                                             permission_codes: %w[manifest_minor_fishermen.view
                                                                  manifest_minor_fishermen.create
                                                                  manifest_minor_fishermen.delete])

            # A plain dofi_officer-platform role (the factory default) rather than a second
            # fisherman-platform role for this company — deliberately fails the fisherman? audience
            # check, so this user is rejected before Pundit's own permission check even runs.
            plain_user = create(:user, role: create(:role), company_profile: @manifest.company_profile,
                                       ic_number: SecureRandom.hex(5), registration_type: "Commercial",
                                       password: MANIFEST_SUB_RESOURCE_TEST_PASSWORD,
                                       password_confirmation: MANIFEST_SUB_RESOURCE_TEST_PASSWORD)
            @plain_headers = auth_headers_for(plain_user, password: MANIFEST_SUB_RESOURCE_TEST_PASSWORD)
          end

          test "create adds a minor fisherman while the manifest is still a draft" do
            params = { minor_fisherman: { full_name: "Ali bin Ahmad", date_of_birth: "2010-03-15", gender: "male",
                                          relationship_with_owner: "Son" } }

            assert_difference("ManifestMinorFisherman.count", 1) do
              post "/api/v1/fisherman/manifests/#{@manifest.id}/minor_fishermen", params: params, headers: @headers,
                                                                                  as: :json
            end

            assert_response :created
          end

          test "create without permission is forbidden" do
            params = { minor_fisherman: { full_name: "Ali", date_of_birth: "2010-03-15", gender: "male",
                                          relationship_with_owner: "Son" } }

            post "/api/v1/fisherman/manifests/#{@manifest.id}/minor_fishermen", params: params,
                                                                                headers: @plain_headers, as: :json

            assert_response :forbidden
          end

          test "create fails once the manifest is no longer editable" do
            @manifest.submit_port_out!
            params = { minor_fisherman: { full_name: "Ali", date_of_birth: "2010-03-15", gender: "male",
                                          relationship_with_owner: "Son" } }

            post "/api/v1/fisherman/manifests/#{@manifest.id}/minor_fishermen", params: params, headers: @headers,
                                                                                as: :json

            assert_response :unprocessable_content
          end

          test "destroy removes the minor fisherman while editable" do
            minor = create(:manifest_minor_fisherman, manifest: @manifest)

            delete "/api/v1/fisherman/manifests/#{@manifest.id}/minor_fishermen/#{minor.id}", headers: @headers

            assert_response :ok
            assert_not ManifestMinorFisherman.exists?(minor.id)
          end
        end
      end
    end
  end
end
