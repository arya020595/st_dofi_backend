# Port-Out states. Commercial manifests wait for Jetty Manager approval, small-scale ones need none.
# Only the transition table lives here; what follows a transition is Manifests::Transition's job.
module Manifest::PortOutWorkflow
  extend ActiveSupport::Concern

  included do
    aasm(:port_out, column: :port_out_status, namespace: :port_out) do
      state :draft, initial: true
      state :pending
      state :amendment_required
      state :approved
      state :submitted

      event :submit_port_out do
        transitions from: :draft, to: :pending,   guard: :commercial?
        transitions from: :draft, to: :submitted, guard: :small_scale?
      end
      event(:approve_port_out)           { transitions from: :pending, to: :approved }
      event(:request_amendment_port_out) { transitions from: :pending, to: :amendment_required }
      event(:resubmit_port_out)          { transitions from: :amendment_required, to: :pending }

      after_all_transitions :record_port_out_history
    end
  end

  private

  def record_port_out_history(actor: nil, remarks: nil, **)
    record_history!("port_out_status", aasm_name: :port_out, actor: actor, remarks: remarks)
  end
end
