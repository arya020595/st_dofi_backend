# Port-In: commercial manifests wait for Jetty Manager approval, small-scale ones need none.
#
# Submitting needs the Capture Report step to exist (reports created, or skipped with a reason). What happens
# next — wait for verification, go to Jetty Manager review, or complete — is decided by
# Manifest#advance_lifecycle!. See docs/manifests/approval-rules-by-category.md.
module Manifest::PortInWorkflow
  extend ActiveSupport::Concern

  included do
    aasm(:port_in, column: :port_in_status, namespace: :port_in) do
      state :draft, initial: true
      state :pending
      state :amendment_required
      state :approved
      state :submitted

      event :submit_port_in do
        transitions from: :draft, to: :pending,   guard: %i[commercial? capture_report_ready?],
                    after: :complete_capture_report!, success: :advance_lifecycle!
        transitions from: :draft, to: :submitted, guard: %i[small_scale? capture_report_ready?],
                    after: :complete_capture_report!, success: :advance_lifecycle!
      end
      event(:approve_port_in) do
        transitions from: :pending, to: :approved, after: :clear_port_in_amendment!,
                    success: :advance_lifecycle!
      end
      event(:request_amendment_port_in) do
        transitions from: :pending, to: :amendment_required, after: :store_port_in_amendment_snapshot!
      end
      event(:resubmit_port_in) { transitions from: :amendment_required, to: :pending, after: :clear_port_in_amendment! }

      after_all_transitions :record_port_in_history
    end
  end

  private

  def record_port_in_history(actor: nil, remarks: nil, **)
    record_history!("port_in_status", aasm_name: :port_in, actor: actor, remarks: remarks)
  end
end
