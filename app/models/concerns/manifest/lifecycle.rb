# The overall manifest status. It is driven by the Port-Out / Port-In workflows and by Capture Report
# verification, and completes once both the Port-In leg and the Capture Report leg are done.
module Manifest::Lifecycle
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

      event(:begin_port_out_review)   { transitions from: :draft, to: :awaiting_port_out_approval }
      event(:advance_to_sea)          { transitions from: %i[draft awaiting_port_out_approval], to: :at_sea }
      event(:begin_port_in_review) do
        transitions from: :capture_report_submitted, to: :awaiting_port_in_approval, guard: :ready_for_port_in_review?
      end
      event(:complete_capture_report) do
        transitions from: %i[at_sea awaiting_port_in_approval], to: :capture_report_submitted
      end
      # success: (not after:) — it fires once the new state is written, whereas after: callbacks still see the
      # pre-transition state (see AASM::InstanceBase#aasm_fired).
      event(:complete_manifest) do
        transitions from: %i[capture_report_submitted awaiting_port_in_approval], to: :completed,
                    guard: :ready_for_completion?,
                    success: %i[record_fishing_gear_usage! clear_capture_report_amendment_snapshot!]
      end

      after_all_transitions :record_manifest_history
    end
  end

  # Port-In (Jetty Manager) and Capture Reports (DoFi Officer) are reviewed independently, in separate requests,
  # so whichever finishes last must move the manifest on. Call this after any step that can complete a leg:
  # it fires whatever the guards now allow. It re-reads the row under a lock so it judges the other leg's
  # committed state, not the instance this request loaded earlier — otherwise two concurrent requests could each
  # see the other's step as unfinished and leave a fully approved manifest stuck.
  def advance_lifecycle!(*, actor: nil, **)
    with_lock do
      complete_manifest!(actor: actor) if may_complete_manifest?
      begin_port_in_review!(actor: actor) if may_begin_port_in_review?
    end
  end

  # True while an amendment request is outstanding — the fisherman edits this same record (via
  # Manifests::Update) then calls the matching resubmit event; there's no separate "amendment form."
  def editable? = draft? || port_out_amendment_required? || port_in_amendment_required?

  private

  # The whole completion rule: both legs are done. Each leg is "settled" on its own terms.
  def ready_for_completion? = port_in_settled? && capture_reports_settled?

  # Commercial only: Port-In is waiting for the Jetty Manager and there is nothing left for a DoFi Officer.
  def ready_for_port_in_review? = commercial? && port_in_pending? && capture_reports_settled?

  # Commercial Port-In needs Jetty Manager approval; small-scale has none, submitting is enough.
  def port_in_settled? = commercial? ? port_in_approved? : port_in_submitted?

  def record_manifest_history(actor: nil, remarks: nil, **)
    record_history!("manifest_status", aasm_name: :manifest, actor: actor, remarks: remarks)
  end

  def record_fishing_gear_usage!(*, **) = Manifests::RecordFishingGearUsage.call(self)
end
