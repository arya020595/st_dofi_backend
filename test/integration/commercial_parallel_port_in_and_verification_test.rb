require "test_helper"
require_relative "../support/committed_database_test"
require_relative "../support/notification_queue_test_helper"

# Port-In approval belongs to the Jetty Manager and Capture Report verification to the DoFi Officer; neither may
# wait for the other, and the manifest completes when the second of the two lands, in either order.
class CommercialParallelPortInAndVerificationTest < ActionDispatch::IntegrationTest
  include CommittedDatabaseTest
  include ActiveJob::TestHelper
  include NotificationQueueTestHelper

  self.use_transactional_tests = false

  setup do
    password = MANIFEST_SUB_RESOURCE_TEST_PASSWORD
    jetty_role = create_role_with_permissions(
      kind: Role::JETTY_MANAGER, name: "Jetty Manager",
      permission_codes: %w[manifest_approvals.list manifest_approvals.view manifest_approvals.approve]
    )
    jetty_manager = create(:user, role: jetty_role, unit: "Docks", position: "Supervisor", contact_no: "71111111",
                                  ic_number: "01-800101", password: password, password_confirmation: password)
    @jetty_headers = auth_headers_for(jetty_manager, password: password)
    @verifier_headers = officer_headers_for(
      permission_codes: %w[capture_report_verifications.list capture_report_verifications.view
                           capture_report_verifications.verify]
    )
    @manifest = create(:manifest, fisherman_category: "commercial")
    Manifests::SubmitPortOut.call(@manifest, actor: nil).value!
    Manifests::ApprovePortOut.call(@manifest, actor: nil).value!
    @report = create(:capture_report, manifest: @manifest)
    Manifests::SubmitPortIn.call(@manifest, actor: nil).value!
  end

  test "jetty manager approves port-in before the DoFi officer verifies, then verification completes it" do
    approve_port_in

    assert_response :ok
    assert_equal %w[approved capture_report_submitted], statuses

    verify_report

    assert_response :ok
    assert_equal %w[approved completed], statuses
  end

  test "DoFi officer verifies before the jetty manager approves port-in, then approval completes it" do
    verify_report

    assert_response :ok
    assert_equal %w[pending awaiting_port_in_approval], statuses

    approve_port_in

    assert_response :ok
    assert_equal %w[approved completed], statuses
  end

  test "repeating either step after completion is rejected and leaves the manifest completed" do
    approve_port_in
    verify_report

    approve_port_in

    assert_response :unprocessable_content

    verify_report

    assert_response :unprocessable_content
    assert_equal %w[approved completed], statuses
  end

  test "jetty approval permission does not allow capture report verification" do
    post "/api/v1/admin/manifests/#{@manifest.id}/capture_reports/#{@report.id}/verify", headers: @jetty_headers

    assert_response :forbidden
    assert_equal "pending_verification", @report.reload.capture_report_status
  end

  test "DoFi verification permission does not allow port-in approval" do
    post "/api/v1/admin/approvals/manifests/#{@manifest.id}/approve_port_in", headers: @verifier_headers

    assert_response :forbidden
    assert_equal "pending", @manifest.reload.port_in_status
  end

  %w[approval verification].each do |action|
    test "#{action} succeeds after commit even when the notification queue fails" do
      gear = create(:companies_fishing_gear, :approved, company_profile: @manifest.company_profile,
                                                        companies_vessel: @manifest.companies_vessel, usage_value: 5)
      create(:fishing_gear_detail, capture_report: @report, companies_fishing_gear: gear, quantity: 2)
      action == "approval" ? verify_report : approve_port_in
      history_count = @manifest.manifest_histories.count
      reports = []
      reporter = recording_error_reporter(reports)
      Rails.error.subscribe(reporter)
      with_failing_notification_queue(SolidQueue::Job::EnqueueError.new("queue unavailable")) do
        action == "approval" ? approve_port_in : verify_report
      end

      assert_response :ok
      assert_equal %w[approved completed], statuses
      assert_equal BigDecimal("7"), gear.reload.usage_value
      assert_equal history_count + 2, @manifest.manifest_histories.count
      assert_equal "port_in_approved", reports.sole.last[:context][:event] if action == "approval"
      assert_equal "capture_report_verified", reports.sole.last[:context][:event] if action == "verification"
      action == "approval" ? approve_port_in : verify_report

      assert_response :unprocessable_content
      assert_equal history_count + 2, @manifest.manifest_histories.count
      assert_equal BigDecimal("7"), gear.reload.usage_value
    ensure
      Rails.error.unsubscribe(reporter) if reporter
    end
  end

  private

  def approve_port_in
    post "/api/v1/admin/approvals/manifests/#{@manifest.id}/approve_port_in", headers: @jetty_headers
  end

  def verify_report
    post "/api/v1/admin/manifests/#{@manifest.id}/capture_reports/#{@report.id}/verify", headers: @verifier_headers
  end

  def statuses
    @manifest.reload.values_at(:port_in_status, :manifest_status)
  end
end
