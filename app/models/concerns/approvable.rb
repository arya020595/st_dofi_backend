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
        transitions from: :amendment_required, to: :pending, after: :clear_amendment
      end
    end
  end

  private

  def stamp_approval(actor: nil, **)
    update!(approved_by_id: actor&.id, approved_at: Time.current)
  end

  def stamp_amendment(remarks: nil, **)
    update!(approved_by_id: nil, approved_at: nil, amendment_remarks: remarks)
  end

  def clear_amendment(**)
    update!(amendment_remarks: nil)
  end
end
