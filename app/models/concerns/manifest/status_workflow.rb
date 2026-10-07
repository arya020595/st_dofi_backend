# The overall manifest status. It is a summary of the Port-Out / Port-In / Capture Report legs, moved only by
# Manifests::Advance (which asks Manifests::LifecycleRules what comes next), never by the legs' own events.
module Manifest::StatusWorkflow
  extend ActiveSupport::Concern

  included do
    # State names deliberately avoid "port_out_pending"/"port_in_pending" — those exact strings
    # collide with the auto-generated namespaced predicates from the :port_out/:port_in machines
    # (namespace "port_out" + state "pending" => method "port_out_pending?"), which would
    # silently overwrite each other (confirmed via `Manifest.new.methods.grep(/port_out/)` emitting
    # an AASM "overriding method" warning before this rename).
    aasm(:manifest, column: :manifest_status) do
      state :draft, initial: true
      state :awaiting_port_out_approval
      state :at_sea
      state :awaiting_port_in_approval
      state :capture_report_submitted
      state :completed

      event(:begin_port_out_review) { transitions from: :draft, to: :awaiting_port_out_approval }
      event(:advance_to_sea) { transitions from: %i[draft awaiting_port_out_approval], to: :at_sea }
      event(:complete_capture_report) do
        transitions from: %i[at_sea awaiting_port_in_approval], to: :capture_report_submitted
      end
      event(:begin_port_in_review) { transitions from: :capture_report_submitted, to: :awaiting_port_in_approval }
      event(:complete_manifest) do
        transitions from: %i[capture_report_submitted awaiting_port_in_approval], to: :completed
      end

      after_all_transitions :record_manifest_history
    end
  end

  # True while an amendment request is outstanding — the fisherman edits this same record (via
  # Manifests::Update) then calls the matching resubmit event; there's no separate "amendment form."
  def editable? = draft? || port_out_amendment_required? || port_in_amendment_required?

  private

  def record_manifest_history(actor: nil, remarks: nil, **)
    record_history!("manifest_status", aasm_name: :manifest, actor: actor, remarks: remarks)
  end
end
