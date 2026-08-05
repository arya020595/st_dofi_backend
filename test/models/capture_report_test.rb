require "test_helper"

class CaptureReportTest < ActiveSupport::TestCase
  test "verify! transitions pending_verification to verified and stamps the reviewer" do
    officer = create(:user)
    report = create(:capture_report)

    report.verify!(actor: officer)

    assert_equal "verified", report.capture_report_status
    assert_equal officer.id, report.reviewed_by_id
    assert_not_nil report.reviewed_at
  end

  test "verify! raises when the report is not pending_verification" do
    report = create(:capture_report)
    report.verify!

    assert_raises(AASM::InvalidTransition) { report.verify! }
    assert_not report.may_verify?
  end

  test "request_amendment! moves to needs_amendment, records remarks, and reopens editing" do
    report = create(:capture_report)

    report.request_amendment!(remarks: "Fishing gear section invalid for this zone")

    assert_equal "needs_amendment", report.capture_report_status
    assert_equal "Fishing gear section invalid for this zone", report.capture_report_remarks
    assert_predicate report, :editable?
  end

  test "resubmit! returns an amended report to pending_verification" do
    report = create(:capture_report)
    report.request_amendment!

    report.resubmit!

    assert_equal "pending_verification", report.capture_report_status
  end

  test "verify! records a manifest_histories row on the parent manifest" do
    report = create(:capture_report)

    assert_difference -> { report.manifest.manifest_histories.count }, 1 do
      report.verify!
    end

    history = report.manifest.manifest_histories.last

    assert_equal %w[capture_report_status pending_verification verified],
                 [history.status_type, history.from_state, history.to_state]
  end

  test "verify! completes the manifest only once ALL of its capture reports are verified" do
    manifest = create(:manifest, fisherman_category: "commercial")
    manifest.submit_port_out!
    manifest.approve_port_out!
    report_one = create(:capture_report, manifest: manifest)
    report_two = create(:capture_report, manifest: manifest)
    manifest.submit_port_in!
    manifest.approve_port_in!

    report_one.verify!

    assert_equal "capture_report_submitted", manifest.reload.manifest_status

    report_two.verify!

    assert_equal "completed", manifest.reload.manifest_status
  end
end

# == Schema Information
#
# Table name: capture_reports
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  capture_report_remarks :text
#  capture_report_status  :string           default("pending_verification"), not null
#  latitude               :decimal(10, 8)
#  longitude              :decimal(11, 8)
#  reviewed_at            :datetime
#  zone_area              :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  manifest_id            :uuid             not null
#  reviewed_by_id         :uuid
#  zone_id                :uuid
#
# Indexes
#
#  index_capture_reports_on_capture_report_status  (capture_report_status)
#  index_capture_reports_on_manifest_id            (manifest_id)
#  index_capture_reports_on_reviewed_by_id         (reviewed_by_id)
#  index_capture_reports_on_zone_id                (zone_id)
#
# Foreign Keys
#
#  fk_rails_...  (manifest_id => manifests.id)
#  fk_rails_...  (reviewed_by_id => users.id)
#  fk_rails_...  (zone_id => zones.id)
#
