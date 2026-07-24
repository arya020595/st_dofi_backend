require "test_helper"

class SmallScaleFullTimeFishermanFlowTest < ActionDispatch::IntegrationTest
  setup do
    @password = "Password123!"

    fisherman_permissions = %w[companies_vessels.view companies_vessels.list companies_vessels.create
                               manifest_list.view manifest_list.list manifest_form.view manifest_form.create
                               capture_reports.view capture_reports.list capture_reports.create].map do |code|
      Permission.find_or_create_by!(code: code) { |p| p.name = code }
    end
    officer_permissions = %w[profiling.view profiling.create fisherman_approvals.view fisherman_approvals.list
                             fisherman_approvals.approve companies_vessel_approvals.view
                             companies_vessel_approvals.list companies_vessel_approvals.approve
                             capture_report_verifications.view capture_report_verifications.list
                             capture_report_verifications.verify].map do |code|
      Permission.find_or_create_by!(code: code) { |p| p.name = code }
    end

    fisherman_role = create(:role, kind: Role::FISHERMAN, name: "Fisherman", permissions: fisherman_permissions)
    officer_role = create(:role, kind: Role::DOFI_OFFICER, name: "DoFi Officer", permissions: officer_permissions)
    @officer = create(:user, role: officer_role, position: "Administrator", unit: "HQ", username: "officer1",
                             password: @password, password_confirmation: @password)
    @officer_headers = auth_headers_for(@officer, password: @password)
    @fisherman_role = fisherman_role
  end

  test "a small-scale full-time fisherman completes the full manifest lifecycle with no Jetty approval" do
    ic_number = "01-999001"

    # 1. DoFi Officer pre-profiles the solo fisherman as an individual-shaped CompanyProfile, with
    # the fisherman themselves as the Owner contact — the same POST /api/v1/company_profiles flow
    # Commercial/Small-Scale (Company) already uses, just with company-shape fields omitted (see
    # CompanyProfile#individual?).
    post "/api/v1/company_profiles",
         params: { company_profile: { registration_type: "Small - Scale (Full-Time)",
                                      owner: { full_name: "Solo Fisherman", gender: "Male",
                                               ic_no: ic_number, ic_colour: "Yellow" } } },
         headers: @officer_headers, as: :json

    assert_response :created
    company_profile_id = response.parsed_body.dig("data", "company_profile", "id")

    # 2. Self-register — matches the pre-profiled Owner contact by IC number, exactly like
    # Commercial/Small-Scale (Company) (Users::RegisterFisherman).
    post "/api/v1/registrations/fisherman",
         params: { user: { name: "Solo Fisherman", ic_number: ic_number,
                           registration_type: "Small - Scale (Full-Time)" } }, as: :json

    assert_response :created
    fisherman = User.find(response.parsed_body.dig("data", "id"))

    assert_equal company_profile_id, fisherman.company_profile_id

    # 3. DoFi Officer approves the registration.
    post "/api/v1/approvals/fishermen/#{fisherman.id}/approve", headers: @officer_headers

    assert_response :ok
    assert_equal "active", fisherman.reload.status

    # 4. Fisherman "logs in" via the mocked BruneiID re-scan.
    post "/api/v1/auth/brunei_id", params: { ic_number: ic_number }, as: :json

    assert_response :ok
    fisherman_headers = { "Authorization" => response.headers["Authorization"] }

    # 5. Fisherman registers a vessel under their own (pre-profiled) company profile.
    post "/api/v1/company_profiles/#{fisherman.company_profile_id}/vessels",
         params: { vessel: { vessel_name: "Solo Boat", boat_number: "BN 1234" } },
         headers: fisherman_headers, as: :json

    assert_response :created
    vessel_id = response.parsed_body.dig("data", "id")

    # 6. DoFi Officer approves the vessel — required before it can be used on a manifest.
    post "/api/v1/approvals/vessels/#{vessel_id}/approve", headers: @officer_headers

    assert_response :ok

    # 7. Fisherman creates a manifest referencing the approved vessel. fisherman_category is
    # derived server-side from the company profile's registration_type, not client-submitted.
    post "/api/v1/fisherman/manifests", params: { manifest: { companies_vessel_id: vessel_id } },
                                        headers: fisherman_headers, as: :json

    assert_response :created
    manifest_data = response.parsed_body["data"]
    manifest_id = manifest_data["id"]

    assert_equal "small_scale_full_time", manifest_data["fisherman_category"]

    # 8. Port-out: small-scale skips Jetty approval entirely, advancing straight to sea.
    post "/api/v1/fisherman/manifests/#{manifest_id}/submit_port_out", headers: fisherman_headers

    assert_response :ok
    data = response.parsed_body["data"]

    assert_equal %w[submitted at_sea], [data["port_out_status"], data["manifest_status"]]

    # 9. Fisherman submits a capture report while at sea.
    post "/api/v1/manifests/#{manifest_id}/capture_reports", params: { capture_report: {} },
                                                             headers: fisherman_headers, as: :json

    assert_response :created
    capture_report_id = response.parsed_body.dig("data", "id")

    # 10. Port-in: small-scale again skips Jetty approval, advancing straight to capture-report-submitted.
    post "/api/v1/fisherman/manifests/#{manifest_id}/submit_port_in", headers: fisherman_headers

    assert_response :ok
    data = response.parsed_body["data"]

    assert_equal %w[submitted capture_report_submitted], [data["port_in_status"], data["manifest_status"]]

    # 11. DoFi Officer verifies the capture report — the manifest auto-completes once every report
    # on it is verified.
    post "/api/v1/manifests/#{manifest_id}/capture_reports/#{capture_report_id}/verify", headers: @officer_headers

    assert_response :ok

    assert_equal "completed", Manifest.find(manifest_id).manifest_status
  end

  test "a commercial fisherman still goes through Jetty Port-Out/Port-In approval, unaffected by small-scale" do
    jetty_permissions = %w[manifest_list.view manifest_list.list manifest_approvals.view manifest_approvals.list
                           manifest_approvals.approve].map do |code|
      Permission.find_or_create_by!(code: code) { |p| p.name = code }
    end
    jetty_role = create(:role, kind: Role::JETTY_MANAGER, name: "Jetty Manager", permissions: jetty_permissions)
    jetty_manager = create(:user, role: jetty_role, unit: "Docks", position: "Supervisor", contact_no: "71111111",
                                  ic_number: "01-999101", password: @password, password_confirmation: @password)
    jetty_headers = auth_headers_for(jetty_manager, password: @password)

    company_profile = create(:company_profile, registration_type: "Commercial")
    vessel = create(:companies_vessel, :approved, company_profile: company_profile)
    fisherman = create(:user, role: @fisherman_role, company_profile: company_profile, ic_number: "01-999102",
                              registration_type: "Commercial", password: @password,
                              password_confirmation: @password)
    fisherman_headers = auth_headers_for(fisherman, password: @password)

    post "/api/v1/fisherman/manifests", params: { manifest: { companies_vessel_id: vessel.id } },
                                        headers: fisherman_headers, as: :json

    assert_response :created
    manifest_data = response.parsed_body["data"]

    assert_equal "commercial", manifest_data["fisherman_category"]
    manifest_id = manifest_data["id"]

    post "/api/v1/fisherman/manifests/#{manifest_id}/submit_port_out", headers: fisherman_headers

    assert_response :ok
    data = response.parsed_body["data"]
    # Commercial waits for Jetty approval — it must NOT jump straight to at_sea like small-scale does.
    assert_equal %w[pending awaiting_port_out_approval], [data["port_out_status"], data["manifest_status"]]

    post "/api/v1/approvals/manifests/#{manifest_id}/approve_port_out", headers: jetty_headers

    assert_response :ok
    data = response.parsed_body["data"]

    assert_equal %w[approved at_sea], [data["port_out_status"], data["manifest_status"]]
  end
end
