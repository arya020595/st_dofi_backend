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

# == Schema Information
#
# Table name: manifests
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  ais_tracking           :boolean          default(FALSE), not null
#  captain_ic_number      :string
#  captain_name           :string
#  capture_report_skipped :boolean          default(FALSE), not null
#  company_name           :string
#  discarded_at           :datetime
#  fisherman_category     :string           not null
#  has_minor_fishermen    :boolean          default(FALSE), not null
#  has_support_vessel     :boolean          default(FALSE), not null
#  latitude               :decimal(10, 8)
#  longitude              :decimal(11, 8)
#  manifest_number        :string           not null
#  manifest_status        :string           default("draft"), not null
#  port_in_area           :string
#  port_in_datetime       :datetime
#  port_in_status         :string           default("draft"), not null
#  port_out_area          :string
#  port_out_datetime      :datetime
#  port_out_status        :string           default("draft"), not null
#  skip_reason_remarks    :text
#  vessel_boat_name       :string
#  vessel_boat_no         :string
#  zone_area              :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  companies_captain_id   :uuid
#  companies_vessel_id    :uuid             not null
#  company_profile_id     :uuid             not null
#  created_by_id          :uuid
#  port_in_id             :uuid
#  port_out_id            :uuid
#  skip_reason_id         :uuid
#  support_vessel_id      :uuid
#  zone_id                :uuid
#
# Indexes
#
#  index_manifests_on_capture_report_skipped  (capture_report_skipped)
#  index_manifests_on_companies_captain_id    (companies_captain_id)
#  index_manifests_on_companies_vessel_id     (companies_vessel_id)
#  index_manifests_on_company_profile_id      (company_profile_id)
#  index_manifests_on_created_by_id           (created_by_id)
#  index_manifests_on_discarded_at            (discarded_at)
#  index_manifests_on_fisherman_category      (fisherman_category)
#  index_manifests_on_manifest_number         (manifest_number) UNIQUE
#  index_manifests_on_manifest_status         (manifest_status)
#  index_manifests_on_port_in_id              (port_in_id)
#  index_manifests_on_port_in_status          (port_in_status)
#  index_manifests_on_port_out_id             (port_out_id)
#  index_manifests_on_port_out_status         (port_out_status)
#  index_manifests_on_skip_reason_id          (skip_reason_id)
#  index_manifests_on_support_vessel_id       (support_vessel_id)
#  index_manifests_on_zone_id                 (zone_id)
#
# Foreign Keys
#
#  fk_rails_...  (companies_captain_id => companies_captains.id)
#  fk_rails_...  (companies_vessel_id => companies_vessels.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (port_in_id => ports.id)
#  fk_rails_...  (port_out_id => ports.id)
#  fk_rails_...  (skip_reason_id => manifest_skip_reasons.id)
#  fk_rails_...  (support_vessel_id => companies_vessels.id)
#  fk_rails_...  (zone_id => zones.id)
#
