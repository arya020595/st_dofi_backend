# Port-Out: commercial manifests wait for Jetty Manager approval, small-scale ones need none.
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
  end

  private

  def record_port_out_history(actor: nil, remarks: nil, **)
    record_history!("port_out_status", aasm_name: :port_out, actor: actor, remarks: remarks)
  end
end
