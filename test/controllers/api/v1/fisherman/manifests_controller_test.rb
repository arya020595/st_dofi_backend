require "test_helper"

module Api
  module V1
    module Fisherman
      class ManifestsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          fisherman_permissions = %w[manifest_list.view manifest_list.list
                                     manifest_list.delete manifest_form.view manifest_form.create
                                     companies_vessels.view companies_vessels.list
                                     companies_vessels.create].map do |code|
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
          get "/api/v1/fisherman/manifests", headers: @plain_headers

          assert_response :forbidden

          get "/api/v1/fisherman/manifests", headers: @fisherman_headers

          assert_response :ok
        end

        test "index scopes a fisherman to their own company's manifests" do
          create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          other_company = create(:company_profile)
          other_vessel = create(:companies_vessel, :approved, company_profile: other_company)
          create(:manifest, company_profile: other_company, companies_vessel: other_vessel)

          get "/api/v1/fisherman/manifests", headers: @fisherman_headers

          assert_response :ok
          assert_equal 1, response.parsed_body["data"].size
        end

        test "show includes is_draft and expense data" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)

          get "/api/v1/fisherman/manifests/#{manifest.id}", headers: @fisherman_headers

          assert_response :ok
          assert response.parsed_body.dig("data", "is_draft")
        end

        test "create builds a draft manifest snapshotting the approved vessel" do
          params = { manifest: { companies_vessel_id: @vessel.id } }

          assert_difference("Manifest.count", 1) do
            post "/api/v1/fisherman/manifests", params: params, headers: @fisherman_headers, as: :json
          end

          data = response.parsed_body["data"]

          assert_equal ["draft", @vessel.vessel_name], [data["manifest_status"], data["vessel_boat_name"]]
          assert data["is_draft"]
        end

        test "create derives fisherman_category from registration_type, ignoring any client value" do
          params = { manifest: { companies_vessel_id: @vessel.id, fisherman_category: "small_scale_full_time" } }

          post "/api/v1/fisherman/manifests", params: params, headers: @fisherman_headers, as: :json

          assert_response :created
          assert_equal "commercial", response.parsed_body.dig("data", "fisherman_category")
        end

        test "create denies a vessel that is not yet approved" do
          pending_vessel = create(:companies_vessel, company_profile: @company_profile)
          params = { manifest: { companies_vessel_id: pending_vessel.id } }

          assert_no_difference("Manifest.count") do
            post "/api/v1/fisherman/manifests", params: params, headers: @fisherman_headers, as: :json
          end
          assert_response :unprocessable_content
        end

        test "create rejects a vessel that belongs to a different company" do
          other_company = create(:company_profile)
          foreign_vessel = create(:companies_vessel, :approved, company_profile: other_company)
          params = { manifest: { companies_vessel_id: foreign_vessel.id } }

          post "/api/v1/fisherman/manifests", params: params, headers: @fisherman_headers, as: :json

          assert_response :unprocessable_content
        end

        test "destroy soft-deletes a draft manifest" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)

          delete "/api/v1/fisherman/manifests/#{manifest.id}", headers: @fisherman_headers

          assert_response :ok
          assert_predicate manifest.reload, :discarded?
        end

        test "destroy refuses a manifest that has already been submitted" do
          submitted = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          submitted.submit_port_out!

          delete "/api/v1/fisherman/manifests/#{submitted.id}", headers: @fisherman_headers

          assert_response :unprocessable_content
          assert_not submitted.reload.discarded?
        end

        test "submit_port_out moves port_out_status to pending" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)

          post "/api/v1/fisherman/manifests/#{manifest.id}/submit_port_out", headers: @fisherman_headers

          assert_response :ok
          assert_equal "pending", manifest.reload.port_out_status
          assert_not response.parsed_body.dig("data", "is_draft")
        end

        test "resubmit_port_out moves an amendment_required manifest back to pending" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          manifest.submit_port_out!
          manifest.request_amendment_port_out!

          post "/api/v1/fisherman/manifests/#{manifest.id}/resubmit_port_out", headers: @fisherman_headers

          assert_response :ok
          assert_equal "pending", manifest.reload.port_out_status
        end

        test "submit_port_in fails without a capture report or a skip reason" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          manifest.submit_port_out!
          manifest.approve_port_out!

          post "/api/v1/fisherman/manifests/#{manifest.id}/submit_port_in", headers: @fisherman_headers

          assert_response :unprocessable_content
        end

        test "submit_port_in succeeds once the capture report has been skipped" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          manifest.submit_port_out!
          manifest.approve_port_out!
          reason = create(:manifest_skip_reason)
          post "/api/v1/fisherman/manifests/#{manifest.id}/skip_capture_report",
               params: { manifest: { skip_reason_id: reason.id, skip_reason_remarks: "Engine issue" } },
               headers: @fisherman_headers, as: :json

          post "/api/v1/fisherman/manifests/#{manifest.id}/submit_port_in", headers: @fisherman_headers

          assert_response :ok
          assert_equal "pending", manifest.reload.port_in_status
        end

        test "tab_counts buckets manifests into port_out, capture_report_and_port_in, and complete" do
          create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          at_sea = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          at_sea.submit_port_out!
          at_sea.approve_port_out!

          get "/api/v1/fisherman/manifests/tab_counts", headers: @fisherman_headers

          assert_response :ok
          data = response.parsed_body["data"]

          assert_equal [1, 1, 0], [data["port_out"], data["capture_report_and_port_in"], data["complete"]]
        end

        test "offline_bundle returns manifest detail alongside reference data" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)

          get "/api/v1/fisherman/manifests/#{manifest.id}/offline_bundle", headers: @fisherman_headers

          assert_response :ok
          data = response.parsed_body["data"]

          assert_equal manifest.id, data.dig("manifest", "id")
          assert_equal %w[dictionaries skip_reasons zones], %w[dictionaries skip_reasons zones] & data.keys
        end
      end
    end
  end
end
