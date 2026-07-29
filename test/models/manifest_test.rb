require "test_helper"

class ManifestTest < ActiveSupport::TestCase
  test "submit_port_out! sends a commercial manifest to pending approval, not straight to sea" do
    manifest = create(:manifest, fisherman_category: "commercial")

    manifest.submit_port_out!

    assert_equal "pending", manifest.port_out_status
    assert_equal "awaiting_port_out_approval", manifest.manifest_status
  end

  test "submit_port_out! sends a small-scale manifest straight to sea, skipping approval" do
    manifest = create(:manifest, :small_scale)

    manifest.submit_port_out!

    assert_equal "submitted", manifest.port_out_status
    assert_equal "at_sea", manifest.manifest_status
  end

  test "submit_port_out! raises when the manifest is not in draft" do
    manifest = create(:manifest, fisherman_category: "commercial")
    manifest.submit_port_out!

    assert_raises(AASM::InvalidTransition) { manifest.submit_port_out! }
    assert_not manifest.may_submit_port_out?
  end

  test "approve_port_out! approves and advances a commercial manifest to sea" do
    manifest = create(:manifest, fisherman_category: "commercial")
    manifest.submit_port_out!

    manifest.approve_port_out!

    assert_equal "approved", manifest.port_out_status
    assert_equal "at_sea", manifest.manifest_status
  end

  test "request_amendment_port_out! moves to amendment_required and reopens editing" do
    manifest = create(:manifest, fisherman_category: "commercial")
    manifest.submit_port_out!

    manifest.request_amendment_port_out!(remarks: "Fix the date")

    assert_equal "amendment_required", manifest.port_out_status
    assert_predicate manifest, :editable?
  end

  test "resubmit_port_out! returns an amended manifest to pending" do
    manifest = create(:manifest, fisherman_category: "commercial")
    manifest.submit_port_out!
    manifest.request_amendment_port_out!

    manifest.resubmit_port_out!

    assert_equal "pending", manifest.port_out_status
  end

  test "may_submit_port_in? is false with no capture report and not skipped" do
    manifest = create(:manifest, fisherman_category: "commercial")
    manifest.submit_port_out!
    manifest.approve_port_out!

    assert_not manifest.may_submit_port_in?
  end

  test "may_submit_port_in? is true once capture_report_skipped is set" do
    manifest = create(:manifest, fisherman_category: "commercial")
    manifest.submit_port_out!
    manifest.approve_port_out!
    manifest.update!(capture_report_skipped: true)

    assert_predicate manifest, :may_submit_port_in?
  end

  test "may_submit_port_in? is true once a capture report exists" do
    manifest = create(:manifest, fisherman_category: "commercial")
    manifest.submit_port_out!
    manifest.approve_port_out!
    create(:capture_report, manifest: manifest)

    assert_predicate manifest, :may_submit_port_in?
  end

  test "commercial? is true only for the commercial category" do
    assert_predicate build(:manifest, fisherman_category: "commercial"), :commercial?
    assert_not build(:manifest, fisherman_category: "commercial").small_scale?
  end

  test "small_scale? is true for all three small-scale categories" do
    %w[small_scale_company small_scale_full_time small_scale_part_time].each do |category|
      manifest = build(:manifest, fisherman_category: category)

      assert_predicate manifest, :small_scale?
      assert_not manifest.commercial?
    end
  end

  test "editable? is true in draft and in either port's amendment_required state" do
    manifest = create(:manifest, fisherman_category: "commercial")

    assert_predicate manifest, :editable?

    manifest.submit_port_out!

    assert_not manifest.editable?

    manifest.request_amendment_port_out!

    assert_predicate manifest, :editable?
  end

  test "support vessel must be approved, from the same company, and distinct from the primary vessel" do
    manifest = create(:manifest)
    manifest.assign_attributes(has_support_vessel: true, support_vessel: manifest.companies_vessel)

    assert_not manifest.valid?
    assert_includes manifest.errors[:support_vessel_id], "must differ from the primary vessel"
  end
end
