# Port-In states. Commercial manifests wait for Jetty Manager approval, small-scale ones need none; either way
# the Capture Report step must exist (reports created, or skipped with a reason) before Port-In can be submitted.
# Only the transition table lives here; the services in app/services/manifests fire the events and what follows.
module Manifest::PortInWorkflow
  extend ActiveSupport::Concern

  included do
    aasm(:port_in, column: :port_in_status, namespace: :port_in, whiny_persistence: true) do
      state :draft, initial: true
      state :pending
      state :amendment_required
      state :approved
      state :submitted

      event :submit_port_in do
        transitions from: :draft, to: :pending,   guard: %i[commercial? capture_report_ready?]
        transitions from: :draft, to: :submitted, guard: %i[small_scale? capture_report_ready?]
      end
      event(:approve_port_in)           { transitions from: :pending, to: :approved }
      event(:request_amendment_port_in) { transitions from: :pending, to: :amendment_required }
      event(:resubmit_port_in)          { transitions from: :amendment_required, to: :pending }

      after_all_transitions :record_port_in_history
    end
  end

  private

  # The Port-In leg is done: commercial needs the Jetty Manager's approval, small-scale only needs submitting.
  def port_in_settled? = commercial? ? port_in_approved? : port_in_submitted?

  def record_port_in_history(actor: nil, remarks: nil, **)
    record_history!("port_in_status", aasm_name: :port_in, actor: actor, remarks: remarks)
  end
end
