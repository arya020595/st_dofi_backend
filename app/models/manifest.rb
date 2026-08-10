# rubocop:disable Metrics/ClassLength -- three related AASM state machines (port_out/port_in/manifest)
# read most clearly kept together; splitting would scatter one cohesive state design across files
# for a marginal line-count win.
class Manifest < ApplicationRecord
  include Discard::Model
  include AASM
  include HasManifestHistory

  belongs_to :companies_vessel
  belongs_to :captain_crew, class_name: "CompaniesCrew", optional: true
  belongs_to :support_vessel, class_name: "CompaniesVessel", optional: true
  belongs_to :company_profile
  belongs_to :port_out, class_name: "Port", optional: true
  belongs_to :port_in, class_name: "Port", optional: true
  belongs_to :zone, optional: true
  belongs_to :skip_reason, class_name: "ManifestSkipReason", optional: true
  belongs_to :created_by, class_name: "User", optional: true

  has_many :crew_manifests, dependent: :destroy
  has_many :manifest_minor_fishermen, dependent: :destroy
  has_many :capture_reports, dependent: :destroy
  has_many :manifest_histories, dependent: :destroy
  has_one :manifest_expense, dependent: :destroy

  COMMERCIAL = "commercial".freeze
  SMALL_SCALE = %w[small_scale_company small_scale_full_time small_scale_part_time].freeze

  validates :manifest_number, presence: true, uniqueness: true
  validates :fisherman_category, presence: true
  validate :support_vessel_is_valid

  def self.ransackable_attributes(_auth_object = nil)
    %w[id manifest_number fisherman_category manifest_status port_out_status port_in_status
       vessel_boat_name vessel_boat_no company_name capture_report_skipped has_minor_fishermen
       company_profile_id companies_vessel_id captain_crew_id discarded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def commercial?  = fisherman_category == COMMERCIAL
  def small_scale? = SMALL_SCALE.include?(fisherman_category)
  def capture_report_ready? = capture_report_skipped? || capture_reports.exists?

  # True while an amendment request is outstanding — the fisherman edits this same record (via
  # Manifests::Update) then calls the matching resubmit event; there's no separate "amendment form."
  def editable? = draft? || port_out_amendment_required? || port_in_amendment_required?

  def manifest_id_for_history = id

  # Row-level aggregate for the Manifest List "Catch Report" column: worst-status-wins across this
  # manifest's capture_reports, mirroring CompanyProfile#owner_contact's simple has_many-aggregation
  # pattern.
  def capture_report_overview_status
    return "skipped" if capture_report_skipped?
    return "not_initiated" if capture_reports.none?
    return "amendment_required" if capture_reports.any?(&:needs_amendment?)
    return "verified" if capture_reports.all?(&:verified?)

    "pending_verification"
  end

  aasm(:port_out, column: :port_out_status, namespace: :port_out) do
    state :draft, initial: true
    state :pending
    state :amendment_required
    state :approved
    state :submitted

    event :submit_port_out do
      transitions from: :draft, to: :pending,   guard: :commercial?,  after: :begin_port_out_review!
      transitions from: :draft, to: :submitted, guard: :small_scale?, after: :advance_to_sea!
    end
    event(:approve_port_out) do
      transitions from: :pending, to: :approved, after: %i[advance_to_sea! clear_port_out_amendment_snapshot!]
    end
    event(:request_amendment_port_out) do
      transitions from: :pending, to: :amendment_required, after: :store_port_out_amendment_snapshot!
    end
    event(:resubmit_port_out) do
      transitions from: :amendment_required, to: :pending, after: :clear_port_out_amendment_snapshot!
    end

    after_all_transitions :record_port_out_history
  end

  aasm(:port_in, column: :port_in_status, namespace: :port_in) do
    state :draft, initial: true
    state :pending
    state :amendment_required
    state :approved
    state :submitted

    event :submit_port_in do
      transitions from: :draft, to: :pending,   guard: %i[commercial? capture_report_ready?],
                  after: :complete_capture_report!
      transitions from: :draft, to: :submitted, guard: %i[small_scale? capture_report_ready?],
                  after: :complete_capture_report!
    end
    event(:approve_port_in) do
      transitions from: :pending, to: :approved, after: %i[clear_port_in_amendment_snapshot! complete_manifest!]
    end
    event(:request_amendment_port_in) do
      transitions from: :pending, to: :amendment_required, after: :store_port_in_amendment_snapshot!
    end
    event(:resubmit_port_in) do
      transitions from: :amendment_required, to: :pending, after: :clear_port_in_amendment_snapshot!
    end

    after_all_transitions :record_port_in_history
  end

  # State names deliberately avoid "port_out_pending"/"port_in_pending" — those exact strings
  # collide with the auto-generated namespaced predicates from the :port_out/:port_in machines
  # above (namespace "port_out" + state "pending" => method "port_out_pending?"), which would
  # silently overwrite each other (confirmed via `Manifest.new.methods.grep(/port_out/)` emitting
  # an AASM "overriding method" warning before this rename).
  aasm(:manifest, column: :manifest_status) do
    state :draft, initial: true
    state :awaiting_port_out_approval
    state :at_sea
    state :awaiting_port_in_approval
    state :capture_report_submitted
    state :completed

    event(:begin_port_out_review)   { transitions from: :draft, to: :awaiting_port_out_approval }
    event(:advance_to_sea)          { transitions from: %i[draft awaiting_port_out_approval], to: :at_sea }
    event(:begin_port_in_review)    { transitions from: :capture_report_submitted, to: :awaiting_port_in_approval }
    # success: (not after:) — auto_complete_if_skipped! checks this same machine's current_state,
    # which after: callbacks see pre-transition (state is written only once event.fire returns, see
    # AASM::InstanceBase#aasm_fired). success: fires post-write via fire_transition_callbacks.
    event(:complete_capture_report) do
      transitions from: %i[at_sea awaiting_port_in_approval], to: :capture_report_submitted,
                  success: :auto_complete_if_skipped!
    end
    event(:complete_manifest) do
      transitions from: %i[capture_report_submitted awaiting_port_in_approval], to: :completed,
                  success: %i[record_fishing_gear_usage! clear_capture_report_amendment_snapshot!]
    end

    after_all_transitions :record_manifest_history
  end

  private

  def support_vessel_is_valid
    validate_support_vessel_presence
    validate_support_vessel_record if support_vessel.present?
  end

  def validate_support_vessel_presence
    return if has_support_vessel? == support_vessel_id.present?

    message = if has_support_vessel?
                "must be provided when a support vessel is used"
              else
                "must be blank when no support vessel is used"
              end
    errors.add(:support_vessel_id, message)
  end

  def validate_support_vessel_record
    errors.add(:support_vessel_id, "must differ from the primary vessel") if support_vessel_id == companies_vessel_id
    validate_support_vessel_company
    errors.add(:support_vessel_id, "must be approved") unless support_vessel.approved?
  end

  def validate_support_vessel_company
    return if support_vessel.company_profile_id == company_profile_id

    errors.add(:support_vessel_id, "must belong to the same company")
  end

  def record_port_out_history(actor: nil, remarks: nil, **)
    record_history!("port_out_status", aasm_name: :port_out, actor: actor, remarks: remarks)
  end

  def record_port_in_history(actor: nil, remarks: nil, **)
    record_history!("port_in_status", aasm_name: :port_in, actor: actor, remarks: remarks)
  end

  def record_manifest_history(actor: nil, remarks: nil, **)
    record_history!("manifest_status", aasm_name: :manifest, actor: actor, remarks: remarks)
  end

  def store_port_out_amendment_snapshot!(*, remarks: nil, **)
    update!(port_out_amendment_remarks: remarks)
  end

  def clear_port_out_amendment_snapshot!(*, **)
    update!(port_out_amendment_remarks: nil)
  end

  def store_port_in_amendment_snapshot!(*, remarks: nil, **)
    update!(port_in_amendment_remarks: remarks)
  end

  def clear_port_in_amendment_snapshot!(*, **)
    update!(port_in_amendment_remarks: nil)
  end

  public

  def sync_capture_report_amendment_snapshot!
    update!(capture_report_amendment_remarks: latest_capture_report_amendment_remarks)
  end

  def clear_capture_report_amendment_snapshot!(*, **)
    update!(capture_report_amendment_remarks: nil)
  end

  def refresh_amendment_snapshots!
    update!(
      port_out_amendment_remarks: latest_manifest_amendment_remarks_for(
        "port_out_status", port_out_amendment_required?
      ),
      port_in_amendment_remarks: latest_manifest_amendment_remarks_for("port_in_status", port_in_amendment_required?),
      capture_report_amendment_remarks: latest_capture_report_amendment_remarks
    )
  end

  private

  # Skipped-report manifests have no CaptureReport to verify — finalize immediately instead of
  # waiting on a verify event that will never come.
  def auto_complete_if_skipped!(actor: nil, **)
    complete_manifest!(actor: actor) if capture_report_skipped? && may_complete_manifest?
  end

  def record_fishing_gear_usage!(*, **)
    usage_totals = FishingGearDetail.joins(:capture_report)
                                    .where(capture_reports: { manifest_id: id })
                                    .where.not(companies_fishing_gear_id: nil)
                                    .group(:companies_fishing_gear_id)
                                    .sum(:quantity)

    usage_totals.each do |gear_id, quantity|
      CompaniesFishingGear.where(id: gear_id)
                          .update_all(["usage_value = COALESCE(usage_value, 0) + ?", quantity]) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def latest_manifest_amendment_remarks_for(status_type, active)
    return nil unless active

    manifest_histories.where(status_type: status_type, to_state: "amendment_required")
                      .order(created_at: :desc)
                      .limit(1)
                      .pick(:remarks)
  end

  def latest_capture_report_amendment_remarks
    capture_reports.where(capture_report_status: "needs_amendment")
                   .order(reviewed_at: :desc, updated_at: :desc)
                   .limit(1)
                   .pick(:capture_report_remarks)
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
# rubocop:enable Metrics/ClassLength
