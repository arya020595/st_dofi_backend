require "test_helper"

module Api
  module V1
    class ManifestsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @password = "Password123!"

        fisherman_permissions = %w[manifest_list.view manifest_list.list manifest_list.update
                                   manifest_list.delete manifest_form.view manifest_form.create
                                   companies_vessels.view companies_vessels.list companies_vessels.create].map do |code|
          Permission.find_or_create_by!(code: code) { |p| p.name = code }
        end

        @fisherman_role = create(:role, kind: Role::FISHERMAN, name: "Fisherman", permissions: fisherman_permissions)
        @no_access_role = create(:role)

        @company_profile = create(:company_profile)
        @fisherman = create(:user, role: @fisherman_role, company_profile: @company_profile,
                                   ic_number: "01-800100", registration_type: "Commercial",
                                   password: @password, password_confirmation: @password)
        @plain_user = create(:user, role: @no_access_role, password: @password, password_confirmation: @password)

        @vessel = create(:companies_vessel, :approved, company_profile: @company_profile)

        @fisherman_headers = auth_headers_for(@fisherman, password: @password)
        @plain_headers = auth_headers_for(@plain_user, password: @password)
      end

      test "index requires the list permission" do
        get "/api/v1/manifests", headers: @plain_headers

        assert_response :forbidden

        get "/api/v1/manifests", headers: @fisherman_headers

        assert_response :ok
      end

      test "index scopes a fisherman to their own company's manifests" do
        create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
        other_company = create(:company_profile)
        other_vessel = create(:companies_vessel, :approved, company_profile: other_company)
        create(:manifest, company_profile: other_company, companies_vessel: other_vessel)

        get "/api/v1/manifests", headers: @fisherman_headers

        assert_response :ok
        assert_equal 1, response.parsed_body["data"].size
      end

      test "create builds a draft manifest snapshotting the approved vessel" do
        params = { manifest: { companies_vessel_id: @vessel.id, fisherman_category: "commercial" } }

        assert_difference("Manifest.count", 1) do
          post "/api/v1/manifests", params: params, headers: @fisherman_headers, as: :json
        end

        data = response.parsed_body["data"]

        assert_equal ["draft", @vessel.vessel_name], [data["manifest_status"], data["vessel_boat_name"]]
      end

      test "create denies a vessel that is not yet approved" do
        pending_vessel = create(:companies_vessel, company_profile: @company_profile)
        params = { manifest: { companies_vessel_id: pending_vessel.id, fisherman_category: "commercial" } }

        assert_no_difference("Manifest.count") do
          post "/api/v1/manifests", params: params, headers: @fisherman_headers, as: :json
        end
        assert_response :unprocessable_content
      end

      test "create rejects a vessel that belongs to a different company" do
        other_company = create(:company_profile)
        foreign_vessel = create(:companies_vessel, :approved, company_profile: other_company)
        params = { manifest: { companies_vessel_id: foreign_vessel.id, fisherman_category: "commercial" } }

        post "/api/v1/manifests", params: params, headers: @fisherman_headers, as: :json

        assert_response :unprocessable_content
      end

      test "destroy soft-deletes a draft manifest" do
        manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)

        delete "/api/v1/manifests/#{manifest.id}", headers: @fisherman_headers

        assert_response :ok
        assert_predicate manifest.reload, :discarded?
      end

      test "destroy refuses a manifest that has already been submitted" do
        submitted = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
        submitted.submit_port_out!

        delete "/api/v1/manifests/#{submitted.id}", headers: @fisherman_headers

        assert_response :unprocessable_content
        assert_not submitted.reload.discarded?
      end
    end
  end
end
