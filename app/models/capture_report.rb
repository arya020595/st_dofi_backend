class CaptureReport < ApplicationRecord
  include AASM
  include HasManifestHistory

  belongs_to :manifest
  belongs_to :zone, optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  has_many :fish_capture_details, dependent: :destroy
  has_many :fishing_gear_details, dependent: :destroy

  before_validation :assign_number_without_database_trigger, on: :create
  validate :manifest_not_skipped, on: :create

  scope :unverified, -> { where.not(capture_report_status: "verified") }

  def self.ransackable_attributes(_auth_object = nil)
    %w[id capture_report_number manifest_id zone_id zone_area capture_report_status capture_report_remarks
       reviewed_by_id reviewed_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def self.capture_report_number_trigger_available?
    return @capture_report_number_trigger_available if defined?(@capture_report_number_trigger_available)

    @capture_report_number_trigger_available = connection.select_value(<<~SQL.squish)
      SELECT to_regclass('public.capture_report_number_sequence') IS NOT NULL
    SQL
  end

  def manifest_id_for_history = manifest_id
  def editable? = pending_verification? || needs_amendment?

  # Only the transition table lives here; stamping the review and moving the manifest on is
  # CaptureReports::Transition's job.
  aasm column: :capture_report_status do
    state :pending_verification, initial: true
    state :verified
    state :needs_amendment

    event(:verify)            { transitions from: :pending_verification, to: :verified }
    event(:request_amendment) { transitions from: :pending_verification, to: :needs_amendment }
    event(:resubmit)          { transitions from: :needs_amendment, to: :pending_verification }

    after_all_transitions :record_catch_history
  end

  private

  def manifest_not_skipped
    errors.add(:base, "Capture report was skipped for this manifest") if manifest&.capture_report_skipped?
  end

  # PostgreSQL functions and triggers are not represented by db/schema.rb. The normal application
  # path uses the BEFORE INSERT trigger from the migration; this fallback keeps schema-loaded test
  # databases functional until they are rebuilt from a SQL structure dump.
  def assign_number_without_database_trigger
    return if capture_report_number.present? || self.class.capture_report_number_trigger_available?

    self.capture_report_number = CaptureReports::NumberGenerator.call
  end

  def record_catch_history(actor: nil, remarks: nil, **)
    record_history!("capture_report_status", actor: actor, remarks: remarks)
  end
end

# == Schema Information
#
# Table name: capture_reports
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  capture_report_number  :string           not null
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
#  index_capture_reports_on_number                 (capture_report_number) UNIQUE
#  index_capture_reports_on_reviewed_by_id         (reviewed_by_id)
#  index_capture_reports_on_zone_id                (zone_id)
#
# Foreign Keys
#
#  fk_rails_...  (manifest_id => manifests.id)
#  fk_rails_...  (reviewed_by_id => users.id)
#  fk_rails_...  (zone_id => zones.id)
#
