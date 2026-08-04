require "test_helper"

module Api
  module V1
    module Approvals
      # rubocop:disable Metrics/ClassLength
      class ManifestsControllerTest < ActionDispatch::IntegrationTest
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
          update_permission = Permission.find_or_create_by!(code: "manifest_list.update") do |p|
            p.name = "manifest_list.update"
          end
          officer_permissions = jetty_permissions + [update_permission]

          @fisherman_role = create(:role, kind: Role::FISHERMAN, name: "Fisherman", permissions: fisherman_permissions)
          @jetty_role = create(:role, kind: Role::JETTY_MANAGER, name: "Jetty Manager", permissions: jetty_permissions)
          @officer_role = create(:role, kind: Role::DOFI_OFFICER, name: "DoFi Officer",
                                        permissions: officer_permissions)
          @no_access_role = create(:role)

          @company_profile = create(:company_profile)
          @fisherman = create(:user, role: @fisherman_role, company_profile: @company_profile,
                                     ic_number: "01-800100", registration_type: "Commercial",
                                     password: @password, password_confirmation: @password)
          @jetty_manager = create(:user, role: @jetty_role, unit: "Docks", position: "Supervisor",
                                         contact_no: "71111111", ic_number: "01-800101",
                                         password: @password, password_confirmation: @password)
          @officer = create(:user, role: @officer_role, position: "Administrator", unit: "HQ", username: "officer1",
                                   ic_number: "01-800102", password: @password, password_confirmation: @password)
          @plain_user = create(:user, role: @no_access_role, password: @password, password_confirmation: @password)

          @vessel = create(:companies_vessel, :approved, company_profile: @company_profile)

          @fisherman_headers = auth_headers_for(@fisherman, password: @password)
          @jetty_headers = auth_headers_for(@jetty_manager, password: @password)
          @officer_headers = auth_headers_for(@officer, password: @password)
          @plain_headers = auth_headers_for(@plain_user, password: @password)
        end

        test "index requires the approvals list permission" do
          get "/api/v1/admin/approvals/manifests", headers: @plain_headers

          assert_response :forbidden

          get "/api/v1/admin/approvals/manifests", headers: @jetty_headers

          assert_response :ok
        end

        test "index sees manifests across every company" do
          create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          other_company = create(:company_profile)
          other_vessel = create(:companies_vessel, :approved, company_profile: other_company)
          create(:manifest, company_profile: other_company, companies_vessel: other_vessel)

          get "/api/v1/admin/approvals/manifests", headers: @jetty_headers

          assert_response :ok
          assert_equal 2, response.parsed_body["data"].size
        end

        test "update lets an officer correct manifest fields" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)

          patch "/api/v1/admin/approvals/manifests/#{manifest.id}", params: { manifest: { zone_area: "Zone 2" } },
                                                                    headers: @officer_headers, as: :json

          assert_response :ok
          assert_equal "Zone 2", manifest.reload.zone_area
        end

        test "update is forbidden for a fisherman" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)

          patch "/api/v1/admin/approvals/manifests/#{manifest.id}", params: { manifest: { zone_area: "Zone 2" } },
                                                                    headers: @fisherman_headers, as: :json

          assert_response :forbidden
        end

        test "approve_port_out advances a pending manifest to sea" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          manifest.submit_port_out!

          post "/api/v1/admin/approvals/manifests/#{manifest.id}/approve_port_out", headers: @jetty_headers

          assert_response :ok
          manifest.reload

          assert_equal %w[approved at_sea], [manifest.port_out_status, manifest.manifest_status]
        end

        test "a fisherman cannot approve their own port-out request" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          manifest.submit_port_out!

          post "/api/v1/admin/approvals/manifests/#{manifest.id}/approve_port_out", headers: @fisherman_headers

          assert_response :forbidden
        end

        test "request_amendment_port_out records the remarks and moves the manifest to amendment_required" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          manifest.submit_port_out!

          post "/api/v1/admin/approvals/manifests/#{manifest.id}/request_amendment_port_out",
               params: { remarks: "Fix the port-out time" }, headers: @jetty_headers, as: :json

          assert_response :ok
          assert_equal "amendment_required", manifest.reload.port_out_status
        end

        test "port_out_approval returns the manifest port-out histories with actor details" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel)
          manifest.submit_port_out!
          post "/api/v1/admin/approvals/manifests/#{manifest.id}/approve_port_out", headers: @jetty_headers

          get "/api/v1/admin/approvals/manifests/#{manifest.id}/port_out_approval", headers: @jetty_headers

          assert_response :ok
          assert_approval_payload(manifest.id, "port_out_status", "approve_port_out!", @jetty_manager.name)
        end

        test "port_in_approval returns the manifest port-in histories with actor details" do
          manifest = create(:manifest, company_profile: @company_profile, companies_vessel: @vessel,
                                       capture_report_skipped: true)
          manifest.submit_port_out!
          manifest.approve_port_out!(actor: @jetty_manager)
          manifest.submit_port_in!
          manifest.approve_port_in!(actor: @jetty_manager)

          get "/api/v1/admin/approvals/manifests/#{manifest.id}/port_in_approval", headers: @jetty_headers

          assert_response :ok
          assert_approval_payload(manifest.id, "port_in_status", "approve_port_in!", @jetty_manager.name)
        end

        private

        def approval_data
          response.parsed_body["data"]
        end

        # rubocop:disable Metrics/AbcSize
        def assert_approval_payload(manifest_id, status_type, action, approver_name)
          data = approval_data
          history = data["histories"].find { |item| item["action"] == action }

          assert_equal manifest_id, data["manifest_id"]
          assert_equal status_type, data["status_type"]
          assert_equal "approved", data["current_status"]
          assert_equal 1, data["histories"].size
          assert_histories_approved(data["histories"])
          assert_not_nil history
          assert_equal approver_name, history.dig("changed_by", "name")
        end
        # rubocop:enable Metrics/AbcSize

        def assert_histories_approved(histories)
          approved_only = histories.all? { |history| history["to_state"] == "approved" }
          assert approved_only
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
