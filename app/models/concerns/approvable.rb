module Approvable
  extend ActiveSupport::Concern

  included do
    include AASM

    belongs_to :approved_by, class_name: "User", optional: true

    aasm column: :approval_status do
      state :pending, initial: true
      state :approved
      state :amendment_required

      event :approve do
        transitions from: :pending, to: :approved, after: :stamp_approval
      end

      event :request_amendment do
        transitions from: :pending, to: :amendment_required, after: :stamp_amendment
      end

      event :resubmit do
        transitions from: %i[amendment_required approved], to: :pending, after: :clear_amendment
      end
    end
  end

  # Called after an owner edits an approvable record's own data (not the approval action itself) —
  # moves it back to pending so the officer reviews the new values, rather than leaving stale
  # approved/amendment_required data on record that no longer reflects what was submitted. A no-op
  # when already pending, so Update services can call this unconditionally after every edit.
  def revert_to_pending_for_edit!
    resubmit! if may_resubmit?
  end

  private

  def stamp_approval(*, actor: nil, **)
    update!(approved_by_id: actor&.id, approved_at: Time.current)
  end

  def stamp_amendment(*, remarks: nil, **)
    update!(approved_by_id: nil, approved_at: nil, amendment_remarks: remarks)
  end

  def clear_amendment(*, **)
    update!(approved_by_id: nil, approved_at: nil, amendment_remarks: nil)
  end
end
