require "test_helper"

class ManifestCompletionTest < ActiveSupport::TestCase
  test "port-in approval lands on capture_report_submitted while a report is still pending verification" do
    manifest = create(:manifest, fisherman_category: "commercial")
    manifest.submit_port_out!
    manifest.approve_port_out!
    create(:capture_report, manifest: manifest)

    manifest.submit_port_in!
    manifest.approve_port_in!

    assert_equal "approved", manifest.port_in_status
    assert_equal "capture_report_submitted", manifest.manifest_status
  end

  test "manifest auto-completes once every capture report is verified" do
    manifest = create(:manifest, fisherman_category: "commercial")
    manifest.submit_port_out!
    manifest.approve_port_out!
    report = create(:capture_report, manifest: manifest)

    manifest.submit_port_in!
    manifest.approve_port_in!
    report.verify!

    assert_equal "completed", manifest.reload.manifest_status
  end

  test "skipped manifest auto-completes immediately once port-in is approved, with no capture report" do
    manifest = create(:manifest, fisherman_category: "commercial")
    manifest.submit_port_out!
    manifest.approve_port_out!
    manifest.update!(capture_report_skipped: true)

    manifest.submit_port_in!
    manifest.approve_port_in!

    assert_equal "completed", manifest.manifest_status
  end

  test "small-scale skipped manifest auto-completes on submit_port_in! alone, no Jetty approval" do
    manifest = create(:manifest, :small_scale)
    manifest.submit_port_out!
    manifest.update!(capture_report_skipped: true)

    manifest.submit_port_in!

    assert_equal "submitted", manifest.port_in_status
    assert_equal "completed", manifest.manifest_status
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

    report.request_amendment!

    assert_equal "amendment_required", manifest.reload.capture_report_overview_status

    report.resubmit!
    report.verify!

    assert_equal "verified", manifest.reload.capture_report_overview_status
  end

  test "every AASM transition records a manifest_histories row" do
    manifest = create(:manifest, fisherman_category: "commercial")

    assert_difference -> { manifest.manifest_histories.count }, 2 do
      manifest.submit_port_out!
    end

    history = manifest.manifest_histories.order(:created_at).last

    assert_equal %w[manifest_status draft awaiting_port_out_approval],
                 [history.status_type, history.from_state, history.to_state]
  end
end
