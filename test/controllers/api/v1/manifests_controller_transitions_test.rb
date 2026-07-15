require "test_helper"

module Api
  module V1
    class ManifestsControllerTransitionsTest < ActionDispatch::IntegrationTest
      setup do
        @password = "Password123!"

        fisherman_permissions = %w[manifest_list.view manifest_list.list manifest_form.view
                                   manifest_form.create].map do |code|
          Permission.find_or_create_by!(code: code) { |p| p.name = code }
        end
        jetty_permissions = %w[manifest_list.view manifest_list.list manifest_approvals.view
                               manifest_approvals.list manifest_approvals.approve
                               manifest_approvals.amendment].map do |code|
          Permission.find_or_create_by!(code: code) { |p| p.name = code }
        end

        @fisherman_role = create(:role, kind: Role::FISHERMAN, name: "Fisherman", permissions: fisherman_permissions)
        @jetty_role = create(:role, kind: Role::JETTY_MANAGER, name: "Jetty Manager", permissions: jetty_permissions)

        @company_profile = create(:company_profile)
        @fisherman = create(:user, role: @fisherman_role, company_profile: @company_profile,
                                   ic_number: "01-800100", registration_type: "Commercial",
                                   password: @password, password_confirmation: @password)
        @jetty_manager = create(:user, role: @jetty_role, unit: "Docks", position: "Supervisor",
                                       contact_no: "71111111", ic_number: "01-800101",
                                       password: @password, password_confirmation: @password)

        @vessel = create(:companies_vessel, :approved, company_profile: @company_profile)

        @fisherman_headers = auth_headers_for(@fisherman, password: @password)
        @jetty_headers = auth_headers_for(@jetty_manager, password: @password)
      end

      test "submit, amend, and resubmit cycles port_out_status through pending and back" do
        manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)

        post "/api/v1/manifests/#{manifest.id}/submit_port_out", headers: @fisherman_headers

        assert_equal "pending", manifest.reload.port_out_status

        post "/api/v1/manifests/#{manifest.id}/request_amendment_port_out",
             params: { remarks: "Fix the port-out time" }, headers: @jetty_headers, as: :json

        assert_equal "amendment_required", manifest.reload.port_out_status

        post "/api/v1/manifests/#{manifest.id}/resubmit_port_out", headers: @fisherman_headers

        assert_equal "pending", manifest.reload.port_out_status
      end

      test "approve_port_out advances a pending manifest to sea" do
        manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
        manifest.submit_port_out!

        post "/api/v1/manifests/#{manifest.id}/approve_port_out", headers: @jetty_headers

        assert_response :ok
        manifest.reload

        assert_equal %w[approved at_sea], [manifest.port_out_status, manifest.manifest_status]
      end

      test "a fisherman cannot approve their own port-out request" do
        manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
        manifest.submit_port_out!

        post "/api/v1/manifests/#{manifest.id}/approve_port_out", headers: @fisherman_headers

        assert_response :forbidden
      end

      test "submit_port_in fails without a capture report or a skip reason" do
        manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
        manifest.submit_port_out!
        manifest.approve_port_out!

        post "/api/v1/manifests/#{manifest.id}/submit_port_in", headers: @fisherman_headers

        assert_response :unprocessable_content
      end

      test "submit_port_in succeeds once the capture report has been skipped" do
        manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
        manifest.submit_port_out!
        manifest.approve_port_out!
        reason = create(:manifest_skip_reason)
        post "/api/v1/manifests/#{manifest.id}/skip_capture_report",
             params: { manifest: { skip_reason_id: reason.id, skip_reason_remarks: "Engine issue" } },
             headers: @fisherman_headers, as: :json

        post "/api/v1/manifests/#{manifest.id}/submit_port_in", headers: @fisherman_headers

        assert_response :ok
        assert_equal "pending", manifest.reload.port_in_status
      end

      test "tab_counts buckets manifests into port_out, capture_report_and_port_in, and complete" do
        create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
        at_sea = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
        at_sea.submit_port_out!
        at_sea.approve_port_out!

        get "/api/v1/manifests/tab_counts", headers: @fisherman_headers

        assert_response :ok
        data = response.parsed_body["data"]

        assert_equal [1, 1, 0], [data["port_out"], data["capture_report_and_port_in"], data["complete"]]
      end

      test "offline_bundle returns manifest detail alongside reference data" do
        manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)

        get "/api/v1/manifests/#{manifest.id}/offline_bundle", headers: @fisherman_headers

        assert_response :ok
        data = response.parsed_body["data"]

        assert_equal manifest.id, data.dig("manifest", "id")
        assert_equal %w[dictionaries skip_reasons zones], %w[dictionaries skip_reasons zones] & data.keys
      end
    end
  end
end
