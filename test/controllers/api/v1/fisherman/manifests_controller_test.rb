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

          @no_access_role = create(:role)

          @company_profile = create(:company_profile)
          @fisherman_role = create(:role, :fisherman, name: "Fisherman", company_profile: @company_profile,
                                                      permissions: fisherman_permissions)
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

        test "show includes changed_by details in manifest_histories" do
          reviewer = create(:user, role: create(:role, kind: Role::JETTY_MANAGER, name: "Jetty Reviewer"),
                                   unit: "Lumut Port", position: "Jetty Supervisor", username: "jetty.manager",
                                   ic_number: "01-900001", contact_no: "81111111")
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          manifest.submit_port_out!
          manifest.approve_port_out!(actor: reviewer)

          get "/api/v1/fisherman/manifests/#{manifest.id}", headers: @fisherman_headers

          assert_response :ok
          assert_review_history(reviewer)
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

        test "create snapshots an approved support vessel when provided" do
          support_vessel = create(:companies_vessel, :approved, company_profile: @company_profile)
          params = { manifest: { companies_vessel_id: @vessel.id, has_support_vessel: true,
                                 support_vessel_id: support_vessel.id } }

          post "/api/v1/fisherman/manifests", params: params, headers: @fisherman_headers, as: :json

          assert_response :created
          data = response.parsed_body["data"]

          assert_equal [support_vessel.id, support_vessel.vessel_name, support_vessel.boat_number],
                       data.values_at("support_vessel_id", "support_vessel_name", "support_vessel_no")
        end

        test "create derives fisherman_category from registration_type, ignoring any client value" do
          params = { manifest: { companies_vessel_id: @vessel.id, fisherman_category: "small_scale_full_time" } }

          post "/api/v1/fisherman/manifests", params: params, headers: @fisherman_headers, as: :json

          assert_response :created
          assert_equal "commercial", response.parsed_body.dig("data", "fisherman_category")
        end

        test "update lets a fisherman add port-out tracking and snapshots an approved support vessel" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          support_vessel = create(:companies_vessel, :approved, company_profile: @company_profile)

          patch "/api/v1/fisherman/manifests/#{manifest.id}",
                params: { manifest: { ais_tracking: true,
                                      has_support_vessel: true,
                                      support_vessel_id: support_vessel.id } },
                headers: @fisherman_headers, as: :json

          assert_response :ok
          data = response.parsed_body["data"]

          assert_equal [true, true, support_vessel.id, support_vessel.vessel_name, support_vessel.boat_number],
                       data.values_at("ais_tracking", "has_support_vessel", "support_vessel_id",
                                      "support_vessel_name", "support_vessel_no")
        end

        test "update sets and snapshots a Boat Captain crew member as captain" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          boat_captain = create(:position, name: "Boat Captain")
          captain = create(:companies_crew, :approved, company_profile: @company_profile, position: boat_captain)

          patch "/api/v1/fisherman/manifests/#{manifest.id}",
                params: { manifest: { captain_crew_id: captain.id } }, headers: @fisherman_headers, as: :json

          assert_response :ok
          data = response.parsed_body["data"]

          assert_equal [captain.id, captain.crew_name, captain.ic_number],
                       data.values_at("captain_crew_id", "captain_name", "captain_ic_number")
        end

        test "update rejects a crew member whose position is not Boat Captain" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          deckhand = create(:companies_crew, :approved, company_profile: @company_profile)

          patch "/api/v1/fisherman/manifests/#{manifest.id}",
                params: { manifest: { captain_crew_id: deckhand.id } }, headers: @fisherman_headers, as: :json

          assert_response :unprocessable_content
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

        test "create snapshots captain_name and captain_ic_number from an approved Boat Captain crew member" do
          boat_captain = create(:position, name: "Boat Captain")
          captain = create(:companies_crew, :approved, company_profile: @company_profile, position: boat_captain)
          params = { manifest: { companies_vessel_id: @vessel.id, captain_crew_id: captain.id } }

          post "/api/v1/fisherman/manifests", params: params, headers: @fisherman_headers, as: :json

          assert_response :created
          data = response.parsed_body["data"]

          assert_equal [captain.id, captain.crew_name, captain.ic_number],
                       data.values_at("captain_crew_id", "captain_name", "captain_ic_number")
        end

        test "create rejects a crew member whose position is not Boat Captain" do
          deckhand = create(:companies_crew, :approved, company_profile: @company_profile)
          params = { manifest: { companies_vessel_id: @vessel.id, captain_crew_id: deckhand.id } }

          assert_no_difference("Manifest.count") do
            post "/api/v1/fisherman/manifests", params: params, headers: @fisherman_headers, as: :json
          end
          assert_response :unprocessable_content
        end

        test "create rejects a Boat Captain crew member belonging to a different company" do
          boat_captain = create(:position, name: "Boat Captain")
          other_company = create(:company_profile)
          foreign_captain = create(:companies_crew, :approved, company_profile: other_company, position: boat_captain)
          params = { manifest: { companies_vessel_id: @vessel.id, captain_crew_id: foreign_captain.id } }

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

        test "skip_capture_report auto-approves port_in and completes the manifest" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          manifest.submit_port_out!
          manifest.approve_port_out!
          reason = create(:manifest_skip_reason)

          post "/api/v1/fisherman/manifests/#{manifest.id}/skip_capture_report",
               params: { manifest: { skip_reason_id: reason.id, skip_reason_remarks: "Engine issue" } },
               headers: @fisherman_headers, as: :json

          assert_response :ok
          assert_equal "approved", manifest.reload.port_in_status
          assert_equal "completed", manifest.reload.manifest_status
        end

        test "skip_capture_report snapshots the skip reason name" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          manifest.submit_port_out!
          manifest.approve_port_out!
          reason = create(:manifest_skip_reason, name: "Engine failure")

          post "/api/v1/fisherman/manifests/#{manifest.id}/skip_capture_report",
               params: { manifest: { skip_reason_id: reason.id, skip_reason_remarks: "Engine issue" } },
               headers: @fisherman_headers, as: :json

          assert_response :ok
          assert_equal [reason.id, "Engine failure"],
                       manifest.reload.values_at(:skip_reason_id, :skip_reason_name)
        end

        test "submit_port_in resets all capture reports to pending_verification" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          manifest.submit_port_out!
          manifest.approve_port_out!
          first_report = create(:capture_report, manifest: manifest)
          second_report = create(:capture_report, manifest: manifest)
          first_report.request_amendment!(remarks: "Fix gear")
          second_report.verify!(actor: create(:user))

          post "/api/v1/fisherman/manifests/#{manifest.id}/submit_port_in", headers: @fisherman_headers

          assert_response :ok
          assert_equal %w[pending_verification pending_verification],
                       [first_report.reload.capture_report_status, second_report.reload.capture_report_status]
        end

        test "resubmit_port_in resets amended capture reports back to pending_verification" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          manifest.submit_port_out!
          manifest.approve_port_out!
          first_report = create(:capture_report, manifest: manifest)
          second_report = create(:capture_report, manifest: manifest)
          manifest.submit_port_in!
          first_report.request_amendment!(remarks: "Fix catch", actor: create(:user))
          second_report.request_amendment!(remarks: "Fix zone", actor: create(:user))

          post "/api/v1/fisherman/manifests/#{manifest.id}/resubmit_port_in", headers: @fisherman_headers

          assert_response :ok
          assert_equal %w[pending_verification pending_verification],
                       [first_report.reload.capture_report_status, second_report.reload.capture_report_status]
        end

        test "update snapshots the port_out name while the manifest is a draft" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          port = create(:port, port_name: "Muara Port")

          patch "/api/v1/fisherman/manifests/#{manifest.id}",
                params: { manifest: { port_out_id: port.id, port_out_area: "Muara Port" } },
                headers: @fisherman_headers, as: :json

          assert_response :ok
          assert_equal [port.id, "Muara Port"],
                       manifest.reload.values_at(:port_out_id, :port_out_name)
        end

        test "update allows a fisherman to fill port-in details while the manifest is at sea" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          manifest.submit_port_out!
          manifest.approve_port_out!
          port = create(:port, port_name: "Lumut Port")

          patch "/api/v1/fisherman/manifests/#{manifest.id}",
                params: { manifest: { port_in_id: port.id,
                                      port_in_area: "Lumut Port",
                                      port_in_datetime: "2026-08-05T00:11:00.000Z" } },
                headers: @fisherman_headers, as: :json

          assert_response :ok
          assert_equal [port.id, "Lumut Port", "Lumut Port"],
                       manifest.reload.values_at(:port_in_id, :port_in_area, :port_in_name)
        end

        test "update allows manifest changes while a capture report amendment is outstanding" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          manifest.submit_port_out!
          manifest.approve_port_out!
          report = create(:capture_report, manifest: manifest)
          manifest.submit_port_in!
          report.request_amendment!(remarks: "Fix capture detail", actor: create(:user))

          patch "/api/v1/fisherman/manifests/#{manifest.id}",
                params: { manifest: { port_in_area: "Muara Port" } },
                headers: @fisherman_headers, as: :json

          assert_response :ok
          assert_equal "Muara Port", manifest.reload.port_in_area
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

        private

        def assert_review_history(reviewer)
          history = review_history

          assert_history_identity(reviewer, history)
          assert_history_reviewer_profile(reviewer, history)
        end

        def review_history
          response.parsed_body["data"]["manifest_histories"].find do |item|
            item["status_type"] == "port_out_status" && item["to_state"] == "approved"
          end
        end

        def assert_history_identity(reviewer, history)
          assert_not_nil history
          assert_equal reviewer.id, history["changed_by_id"]
          assert_equal reviewer.id, history.dig("changed_by", "id")
          assert_equal reviewer.name, history.dig("changed_by", "name")
        end

        def assert_history_reviewer_profile(reviewer, history)
          assert_equal reviewer.username, history.dig("changed_by", "username")
          assert_equal reviewer.unit, history.dig("changed_by", "unit")
          assert_equal reviewer.position, history.dig("changed_by", "position")
        end
      end
    end
  end
end
