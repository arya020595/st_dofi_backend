require "test_helper"

# rubocop:disable Metrics/ClassLength
class ManifestCompletionTest < ActiveSupport::TestCase
  test "submit_port_in lands on capture_report_submitted while a report is still pending verification" do
    manifest = create(:manifest, fisherman_category: "commercial")
    Manifests::SubmitPortOut.call(manifest, actor: nil).value!
    Manifests::ApprovePortOut.call(manifest, actor: nil).value!
    create(:capture_report, manifest: manifest)

    Manifests::SubmitPortIn.call(manifest, actor: nil).value!

    assert_equal "pending", manifest.port_in_status
    assert_equal "capture_report_submitted", manifest.manifest_status
  end

  test "manifest moves to awaiting_port_in_approval once every capture report is verified" do
    manifest = create(:manifest, fisherman_category: "commercial")
    Manifests::SubmitPortOut.call(manifest, actor: nil).value!
    Manifests::ApprovePortOut.call(manifest, actor: nil).value!
    report = create(:capture_report, manifest: manifest)

    Manifests::SubmitPortIn.call(manifest, actor: nil).value!
    CaptureReports::Verify.call(report, actor: nil).value!

    assert_equal "awaiting_port_in_approval", manifest.reload.manifest_status
  end

  test "approve_port_in completes the manifest once capture reports are verified" do
    manifest = create(:manifest, fisherman_category: "commercial")
    Manifests::SubmitPortOut.call(manifest, actor: nil).value!
    Manifests::ApprovePortOut.call(manifest, actor: nil).value!
    report = create(:capture_report, manifest: manifest)

    Manifests::SubmitPortIn.call(manifest, actor: nil).value!
    CaptureReports::Verify.call(report, actor: nil).value!
    Manifests::ApprovePortIn.call(manifest, actor: nil).value!

    assert_equal "completed", manifest.reload.manifest_status
  end

  test "commercial manifest completes only after a post-port-in amendment is resubmitted and verified" do
    manifest = create(:manifest, fisherman_category: "commercial")
    Manifests::SubmitPortOut.call(manifest, actor: nil).value!
    Manifests::ApprovePortOut.call(manifest, actor: nil).value!
    report = create(:capture_report, manifest: manifest)

    Manifests::SubmitPortIn.call(manifest, actor: nil).value!
    Manifests::ApprovePortIn.call(manifest, actor: nil).value!

    assert_equal %w[approved capture_report_submitted pending_verification],
                 [manifest.port_in_status, manifest.manifest_status, report.capture_report_status]

    CaptureReports::RequestAmendment.call(report, actor: nil, remarks: "Correct the catch quantity").value!
    CaptureReports::Resubmit.call(report, actor: nil).value!
    CaptureReports::Verify.call(report, actor: nil).value!

    assert_equal %w[approved completed verified],
                 [manifest.reload.port_in_status, manifest.manifest_status, report.reload.capture_report_status]
  end

  test "port-in amendment requested while a report is pending resumes review once resubmitted and verified" do
    manifest = create(:manifest, fisherman_category: "commercial")
    Manifests::SubmitPortOut.call(manifest, actor: nil).value!
    Manifests::ApprovePortOut.call(manifest, actor: nil).value!
    report = create(:capture_report, manifest: manifest)
    Manifests::SubmitPortIn.call(manifest, actor: nil).value!

    Manifests::RequestAmendmentPortIn.call(manifest, actor: nil, remarks: "Fix the port-in time").value!
    CaptureReports::Verify.call(report, actor: nil).value!

    assert_equal %w[amendment_required capture_report_submitted verified],
                 [manifest.reload.port_in_status, manifest.manifest_status, report.reload.capture_report_status]

    Manifests::ResubmitPortIn.call(manifest, actor: nil).value!

    assert_equal "awaiting_port_in_approval", manifest.reload.manifest_status

    Manifests::ApprovePortIn.call(manifest, actor: nil).value!

    assert_equal %w[approved completed], [manifest.reload.port_in_status, manifest.manifest_status]
  end

  test "commercial manifest with a skipped capture report completes on port-in approval" do
    manifest = create(:manifest, fisherman_category: "commercial", capture_report_skipped: true)
    Manifests::SubmitPortOut.call(manifest, actor: nil).value!
    Manifests::ApprovePortOut.call(manifest, actor: nil).value!
    Manifests::SubmitPortIn.call(manifest, actor: nil).value!

    assert_equal "awaiting_port_in_approval", manifest.manifest_status

    Manifests::ApprovePortIn.call(manifest, actor: nil).value!

    assert_equal %w[approved completed], [manifest.reload.port_in_status, manifest.manifest_status]
  end

  # Port-In approval (Jetty Manager) and report verification (DoFi Officer) are separate requests. Each one's
  # finalizer must act on the committed state of the other, not on a manifest instance loaded before it.
  test "verifying the last report completes the manifest even if port-in was approved after the report loaded" do
    manifest = create(:manifest, fisherman_category: "commercial")
    Manifests::SubmitPortOut.call(manifest, actor: nil).value!
    Manifests::ApprovePortOut.call(manifest, actor: nil).value!
    create(:capture_report, manifest: manifest)
    Manifests::SubmitPortIn.call(manifest, actor: nil).value!

    report = CaptureReport.find_by!(manifest: manifest)
    report.manifest # the DoFi Officer's request has loaded the manifest while Port-In was still pending
    Manifests::ApprovePortIn.call(Manifest.find(manifest.id), actor: nil).value!
    CaptureReports::Verify.call(report, actor: nil).value!

    assert_equal "completed", manifest.reload.manifest_status
  end

  test "verifying the last report starts port-in review even if port-in was resubmitted after the report loaded" do
    manifest = create(:manifest, fisherman_category: "commercial")
    Manifests::SubmitPortOut.call(manifest, actor: nil).value!
    Manifests::ApprovePortOut.call(manifest, actor: nil).value!
    create(:capture_report, manifest: manifest)
    Manifests::SubmitPortIn.call(manifest, actor: nil).value!
    Manifests::RequestAmendmentPortIn.call(manifest, actor: nil, remarks: "Fix the port-in time").value!

    report = CaptureReport.find_by!(manifest: manifest)
    report.manifest # loaded while Port-In still awaited the fisherman's amendment
    Manifests::ResubmitPortIn.call(Manifest.find(manifest.id), actor: nil).value!
    CaptureReports::Verify.call(report, actor: nil).value!

    assert_equal %w[pending awaiting_port_in_approval],
                 [manifest.reload.port_in_status, manifest.manifest_status]
  end

  test "complete_manifest increments usage_value from capture report fishing gear quantities" do
    manifest = create(:manifest, fisherman_category: "commercial")
    Manifests::SubmitPortOut.call(manifest, actor: nil).value!
    Manifests::ApprovePortOut.call(manifest, actor: nil).value!
    report_one = create(:capture_report, manifest: manifest)
    report_two = create(:capture_report, manifest: manifest)
    company_gear = create(:companies_fishing_gear, :approved,
                          company_profile: manifest.company_profile,
                          companies_vessel: manifest.companies_vessel,
                          usage_value: 5)
    create(:fishing_gear_detail, capture_report: report_one, companies_fishing_gear: company_gear, quantity: 2)
    create(:fishing_gear_detail, capture_report: report_two, companies_fishing_gear: company_gear, quantity: 3)

    Manifests::SubmitPortIn.call(manifest, actor: nil).value!
    CaptureReports::Verify.call(report_one, actor: nil).value!
    CaptureReports::Verify.call(report_two, actor: nil).value!
    Manifests::ApprovePortIn.call(manifest, actor: nil).value!

    assert_equal BigDecimal("10"), company_gear.reload.usage_value
  end

  test "commercial skipped manifest goes straight to jetty review without DoFi verification" do
    manifest = create(:manifest, fisherman_category: "commercial")
    Manifests::SubmitPortOut.call(manifest, actor: nil).value!
    Manifests::ApprovePortOut.call(manifest, actor: nil).value!
    manifest.update!(capture_report_skipped: true)

    Manifests::SubmitPortIn.call(manifest, actor: nil).value!

    assert_equal %w[pending awaiting_port_in_approval], manifest.reload.values_at(:port_in_status, :manifest_status)

    Manifests::ApprovePortIn.call(manifest, actor: nil).value!

    assert_equal %w[approved completed], manifest.values_at(:port_in_status, :manifest_status)
  end

  %w[small_scale_company small_scale_full_time small_scale_part_time].each do |category|
    test "#{category} skipped manifest completes port-in with no approval" do
      manifest = create(:manifest, fisherman_category: category)
      Manifests::SubmitPortOut.call(manifest, actor: nil).value!
      manifest.update!(capture_report_skipped: true)

      Manifests::SubmitPortIn.call(manifest, actor: nil).value!

      assert_equal "submitted", manifest.port_in_status
      assert_equal "completed", manifest.reload.manifest_status
      assert_not manifest.may_approve_port_in?
    end
  end

  test "small-scale completion increments usage_value after final capture report verification" do
    manifest = create(:manifest, :small_scale)
    Manifests::SubmitPortOut.call(manifest, actor: nil).value!
    report = create(:capture_report, manifest: manifest)
    company_gear = create(:companies_fishing_gear, :approved,
                          company_profile: manifest.company_profile,
                          companies_vessel: manifest.companies_vessel,
                          usage_value: nil)
    create(:fishing_gear_detail, capture_report: report, companies_fishing_gear: company_gear, quantity: 4)

    Manifests::SubmitPortIn.call(manifest, actor: nil).value!
    CaptureReports::Verify.call(report, actor: nil).value!

    assert_equal "completed", manifest.reload.manifest_status
    assert_equal BigDecimal("4"), company_gear.reload.usage_value
  end

  test "capture_report_overview_status is not_initiated with no reports and not skipped" do
    manifest = create(:manifest, fisherman_category: "commercial")

    assert_equal "not_initiated", manifest.capture_report_overview_status
  end

  test "capture_report_overview_status is skipped once capture_report_skipped is set" do
    manifest = create(:manifest, fisherman_category: "commercial")
    manifest.update!(capture_report_skipped: true)

    assert_equal "skipped", manifest.capture_report_overview_status
  end

  test "capture_report_overview_status tracks a report through amendment and verification" do
    manifest = create(:manifest, fisherman_category: "commercial")
    report = create(:capture_report, manifest: manifest)

    assert_equal "pending_verification", manifest.capture_report_overview_status

    CaptureReports::RequestAmendment.call(report, actor: nil, remarks: "Fix the catch quantity").value!

    assert_equal "amendment_required", manifest.reload.capture_report_overview_status

    CaptureReports::Resubmit.call(report, actor: nil).value!
    CaptureReports::Verify.call(report, actor: nil).value!

    assert_equal "verified", manifest.reload.capture_report_overview_status
  end

  test "every AASM transition records a manifest_histories row" do
    manifest = create(:manifest, fisherman_category: "commercial")

    assert_difference -> { manifest.manifest_histories.count }, 2 do
      Manifests::SubmitPortOut.call(manifest, actor: nil).value!
    end

    history = manifest.manifest_histories.order(:created_at).last

    assert_equal %w[manifest_status draft awaiting_port_out_approval],
                 [history.status_type, history.from_state, history.to_state]
  end
end
# rubocop:enable Metrics/ClassLength
