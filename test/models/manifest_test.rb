require "test_helper"

class ManifestTest < ActiveSupport::TestCase
  test "submit_port_out! sends a commercial manifest to pending approval, not straight to sea" do
    manifest = create(:manifest, fisherman_category: "commercial")

    fire_manifest(manifest, :submit_port_out)

    assert_equal "pending", manifest.port_out_status
    assert_equal "awaiting_port_out_approval", manifest.manifest_status
  end

  test "submit_port_out! sends a small-scale manifest straight to sea, skipping approval" do
    manifest = create(:manifest, :small_scale)

    fire_manifest(manifest, :submit_port_out)

    assert_equal "submitted", manifest.port_out_status
    assert_equal "at_sea", manifest.manifest_status
  end

  test "submit_port_out! raises when the manifest is not in draft" do
    manifest = create(:manifest, fisherman_category: "commercial")
    fire_manifest(manifest, :submit_port_out)

    assert_raises(AASM::InvalidTransition) { manifest.submit_port_out! }
    assert_not manifest.may_submit_port_out?
  end

  test "approve_port_out! approves and advances a commercial manifest to sea" do
    manifest = create(:manifest, fisherman_category: "commercial")
    fire_manifest(manifest, :submit_port_out)

    fire_manifest(manifest, :approve_port_out)

    assert_equal "approved", manifest.port_out_status
    assert_equal "at_sea", manifest.manifest_status
  end

  test "request_amendment_port_out! moves to amendment_required and reopens editing" do
    manifest = create(:manifest, fisherman_category: "commercial")
    fire_manifest(manifest, :submit_port_out)

    fire_manifest(manifest, :request_amendment_port_out, remarks: "Fix the date")

    assert_equal "amendment_required", manifest.port_out_status
    assert_equal "Fix the date", manifest.port_out_amendment_remarks
    assert_predicate manifest, :editable?
  end

  test "resubmit_port_out! returns an amended manifest to pending" do
    manifest = create(:manifest, fisherman_category: "commercial")
    fire_manifest(manifest, :submit_port_out)
    fire_manifest(manifest, :request_amendment_port_out)

    fire_manifest(manifest, :resubmit_port_out)

    assert_equal "pending", manifest.port_out_status
    assert_nil manifest.port_out_amendment_remarks
  end

  test "request_amendment_port_in! stores remarks and resubmit_port_in! clears them" do
    manifest = create(:manifest, fisherman_category: "commercial")
    report = create(:capture_report, manifest: manifest)
    fire_manifest(manifest, :submit_port_out)
    fire_manifest(manifest, :approve_port_out)
    fire_manifest(manifest, :submit_port_in)
    fire_report(report, :verify)

    fire_manifest(manifest, :request_amendment_port_in, remarks: "Fix port-in time")

    assert_equal "Fix port-in time", manifest.port_in_amendment_remarks

    fire_manifest(manifest, :resubmit_port_in)

    assert_nil manifest.port_in_amendment_remarks
  end

  test "may_submit_port_in? is false with no capture report and not skipped" do
    manifest = create(:manifest, fisherman_category: "commercial")
    fire_manifest(manifest, :submit_port_out)
    fire_manifest(manifest, :approve_port_out)

    assert_not manifest.may_submit_port_in?
  end

  test "may_submit_port_in? is true once capture_report_skipped is set" do
    manifest = create(:manifest, fisherman_category: "commercial")
    fire_manifest(manifest, :submit_port_out)
    fire_manifest(manifest, :approve_port_out)
    manifest.update!(capture_report_skipped: true)

    assert_predicate manifest, :may_submit_port_in?
  end

  test "may_submit_port_in? is true once a capture report exists" do
    manifest = create(:manifest, fisherman_category: "commercial")
    fire_manifest(manifest, :submit_port_out)
    fire_manifest(manifest, :approve_port_out)
    create(:capture_report, manifest: manifest)

    assert_predicate manifest, :may_submit_port_in?
  end

  test "capture_report_skipped cannot be set once capture reports exist" do
    manifest = create(:manifest)
    create(:capture_report, manifest: manifest)

    manifest.capture_report_skipped = true

    assert_not manifest.valid?
    assert_includes manifest.errors[:base], "Capture report cannot be skipped once capture reports have been created"
  end

  test "an already-skipped manifest that also has reports stays saveable" do
    manifest = create(:manifest)
    create(:capture_report, manifest: manifest)
    manifest.update_column(:capture_report_skipped, true) # rubocop:disable Rails/SkipsModelValidations

    assert manifest.update(port_in_area: "Serasa Port")
  end

  test "exactly one submit_port_in transition applies to each category and capture report state" do
    %w[commercial small_scale_company small_scale_full_time small_scale_part_time].each do |category|
      [true, false].each do |skipped|
        manifest = create(:manifest, fisherman_category: category, capture_report_skipped: skipped)
        create(:capture_report, manifest: manifest) unless skipped

        assert_equal 1, matching_submit_port_in_transitions(manifest).size, "#{category} skipped=#{skipped}"
      end
    end
  end

  test "chained port-in transitions on a skipped manifest record the actor" do
    actor = create(:user)
    manifest = create(:manifest, fisherman_category: "small_scale_full_time", capture_report_skipped: true)
    fire_manifest(manifest, :submit_port_out)

    fire_manifest(manifest, :submit_port_in, actor: actor)

    histories = manifest.manifest_histories.where(action: %w[complete_capture_report! complete_manifest!])

    assert_equal [actor.id], histories.pluck(:changed_by_id).uniq
    assert_equal 2, histories.count
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

    fire_manifest(manifest, :submit_port_out)

    assert_not manifest.editable?

    fire_manifest(manifest, :request_amendment_port_out)

    assert_predicate manifest, :editable?
  end

  test "support vessel links must be distinct from the primary vessel" do
    manifest = create(:manifest)
    support_vessel = manifest.manifest_support_vessels.build(companies_vessel: manifest.companies_vessel,
                                                             vessel_name: manifest.companies_vessel.vessel_name,
                                                             boat_number: manifest.companies_vessel.boat_number)

    assert_not support_vessel.valid?
    assert_includes support_vessel.errors[:companies_vessel], "must differ from the primary vessel"
  end

  test "destroy is blocked when an owned capture report exists" do
    manifest = create(:manifest)
    create(:capture_report, manifest: manifest)

    assert_not manifest.destroy
    assert_includes manifest.errors[:base], "Cannot delete record because dependent capture reports exist"
    assert_raises(ActiveRecord::RecordNotDestroyed) { manifest.destroy! }
  end

  test "destroy succeeds when the manifest has no owned children" do
    manifest = create(:manifest)

    assert manifest.destroy
  end

  private

  def matching_submit_port_in_transitions(manifest)
    manifest.aasm(:port_in).events.find { |event| event.name == :submit_port_in }
                                  .transitions.select { |transition| transition.allowed?(manifest) }
  end
end

# == Schema Information
#
# Table name: manifests
# Database name: primary
#
#  id                               :uuid             not null, primary key
#  ais_tracking                     :boolean          default(FALSE), not null
#  captain_ic_number                :string
#  captain_name                     :string
#  capture_report_amendment_remarks :text
#  capture_report_skipped           :boolean          default(FALSE), not null
#  company_name                     :string
#  discarded_at                     :datetime
#  fisherman_category               :string           not null
#  has_minor_fishermen              :boolean          default(FALSE), not null
#  has_support_vessel               :boolean          default(FALSE), not null
#  latitude                         :decimal(10, 8)
#  longitude                        :decimal(11, 8)
#  manifest_number                  :string           not null
#  manifest_status                  :string           default("draft"), not null
#  port_in_amendment_remarks        :text
#  port_in_area                     :string
#  port_in_datetime                 :datetime
#  port_in_name                     :string
#  port_in_status                   :string           default("draft"), not null
#  port_out_amendment_remarks       :text
#  port_out_area                    :string
#  port_out_datetime                :datetime
#  port_out_name                    :string
#  port_out_status                  :string           default("draft"), not null
#  skip_reason_name                 :string
#  skip_reason_remarks              :text
#  support_vessel_name              :string
#  support_vessel_no                :string
#  vessel_boat_name                 :string
#  vessel_boat_no                   :string
#  zone_area                        :string
#  zone_name                        :string
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  captain_crew_id                  :uuid
#  companies_vessel_id              :uuid             not null
#  company_profile_id               :uuid             not null
#  created_by_id                    :uuid
#  port_in_id                       :uuid
#  port_out_id                      :uuid
#  skip_reason_id                   :uuid
#  support_vessel_id                :uuid
#  zone_id                          :uuid
#
# Indexes
#
#  index_manifests_on_captain_crew_id         (captain_crew_id)
#  index_manifests_on_capture_report_skipped  (capture_report_skipped)
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
#  fk_rails_...  (captain_crew_id => companies_crews.id)
#  fk_rails_...  (companies_vessel_id => companies_vessels.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (port_in_id => ports.id)
#  fk_rails_...  (port_out_id => ports.id)
#  fk_rails_...  (skip_reason_id => manifest_skip_reasons.id)
#  fk_rails_...  (support_vessel_id => companies_vessels.id)
#  fk_rails_...  (zone_id => zones.id)
#
