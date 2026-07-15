require "test_helper"

module Api
  module V1
    module Manifests
      class MinorFishermenControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          permissions = %w[view create delete].map do |action|
            Permission.find_or_create_by!(code: "manifest_minor_fishermen.#{action}") do |p|
              p.name = "Minors - #{action}"
            end
          end
          @role = create(:role, permissions: permissions)
          @no_access_role = create(:role)

          @manifest = create(:manifest, :small_scale)
          @user = create(:user, role: @role, company_profile: @manifest.company_profile,
                                password: @password, password_confirmation: @password)
          @plain_user = create(:user, role: @no_access_role, company_profile: @manifest.company_profile,
                                      password: @password, password_confirmation: @password)

          @headers = auth_headers_for(@user, password: @password)
          @plain_headers = auth_headers_for(@plain_user, password: @password)
        end

        test "create adds a minor fisherman while the manifest is still a draft" do
          params = { minor_fisherman: { full_name: "Ali bin Ahmad", date_of_birth: "2010-03-15", gender: "male",
                                        relationship_with_owner: "Son" } }

          assert_difference("ManifestMinorFisherman.count", 1) do
            post "/api/v1/manifests/#{@manifest.id}/minor_fishermen", params: params, headers: @headers, as: :json
          end

          assert_response :created
        end

        test "create without permission is forbidden" do
          params = { minor_fisherman: { full_name: "Ali", date_of_birth: "2010-03-15", gender: "male",
                                        relationship_with_owner: "Son" } }

          post "/api/v1/manifests/#{@manifest.id}/minor_fishermen", params: params, headers: @plain_headers, as: :json

          assert_response :forbidden
        end

        test "create fails once the manifest is no longer editable" do
          @manifest.submit_port_out!
          params = { minor_fisherman: { full_name: "Ali", date_of_birth: "2010-03-15", gender: "male",
                                        relationship_with_owner: "Son" } }

          post "/api/v1/manifests/#{@manifest.id}/minor_fishermen", params: params, headers: @headers, as: :json

          assert_response :unprocessable_content
        end

        test "destroy removes the minor fisherman while editable" do
          minor = create(:manifest_minor_fisherman, manifest: @manifest)

          delete "/api/v1/manifests/#{@manifest.id}/minor_fishermen/#{minor.id}", headers: @headers

          assert_response :ok
          assert_not ManifestMinorFisherman.exists?(minor.id)
        end
      end
    end
  end
end
