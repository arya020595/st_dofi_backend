class CaptureReport < ApplicationRecord
  include AASM
  include HasManifestHistory

  belongs_to :manifest
  belongs_to :zone, optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  has_many :fish_capture_details, dependent: :destroy
  has_one :capture_report_expense, dependent: :destroy
  has_many :fishing_gear_details, dependent: :destroy

  def self.ransackable_attributes(_auth_object = nil)
    %w[id manifest_id zone_id zone_area capture_report_status capture_report_remarks
       reviewed_by_id reviewed_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def manifest_id_for_history = manifest_id
  def editable? = pending_verification? || needs_amendment?

  aasm column: :capture_report_status do
    state :pending_verification, initial: true
    state :verified
    state :needs_amendment

    # success: (not after:) — stamp_review_and_maybe_complete! checks this report's own verified?
    # state via manifest.capture_reports.all?(&:verified?), which after: callbacks see pre-persist
    # (same reasoning as Manifest#auto_complete_if_skipped!, see app/models/manifest.rb).
    event(:verify) do
      transitions from: :pending_verification, to: :verified, success: :stamp_review_and_maybe_complete!
    end
    event(:request_amendment) { transitions from: :pending_verification, to: :needs_amendment, after: :stamp_review! }
    event(:resubmit) { transitions from: :needs_amendment, to: :pending_verification }

    after_all_transitions :record_catch_history
  end

  private

  def record_catch_history(actor: nil, remarks: nil, **)
    record_history!("capture_report_status", actor: actor, remarks: remarks)
  end

  def stamp_review!(actor: nil, remarks: nil, **)
    update!(reviewed_by_id: actor&.id, reviewed_at: Time.current, capture_report_remarks: remarks)
  end

  def stamp_review_and_maybe_complete!(actor: nil, **)
    update!(reviewed_by_id: actor&.id, reviewed_at: Time.current)
    return unless manifest.capture_reports.all?(&:verified?) && manifest.may_complete_manifest?

    manifest.complete_manifest!(actor: actor)
  end
end
