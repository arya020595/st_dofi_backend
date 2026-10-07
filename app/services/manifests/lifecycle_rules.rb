module Manifests
  # The manifest's progress rules, read-only. A manifest has two independent legs:
  #
  #   Port-In         commercial: approved by the Jetty Manager; small-scale: submitting is enough
  #   Capture Reports skipped with a reason, or every report verified by a DoFi Officer
  #
  # It completes when both legs are settled. See docs/manifests/lifecycle-status.md.
  class LifecycleRules
    delegate :commercial?, :capture_report_skipped?, :capture_reports, :manifest_status,
             :port_out_pending?, :port_out_submitted?, :port_out_approved?,
             :port_in_pending?, :port_in_submitted?, :port_in_approved?, to: :@manifest

    def initialize(manifest)
      @manifest = manifest
    end

    def complete? = port_in_settled? && capture_reports_settled?

    def port_in_review_ready? = commercial? && port_in_pending? && capture_reports_settled?

    # The next manifest_status event the legs now allow, or nil when the manifest has to wait. One method per
    # status below, so the whole progression reads as a table.
    def next_event = send(:"from_#{manifest_status}")

    private

    def port_in_settled? = commercial? ? port_in_approved? : port_in_submitted?

    def capture_reports_settled? = capture_report_skipped? || all_capture_reports_verified?

    # Reads the database, not the loaded association, so it judges committed state.
    def all_capture_reports_verified? = capture_reports.exists? && !capture_reports.unverified.exists?

    def from_draft
      return :begin_port_out_review if port_out_pending?

      :advance_to_sea if port_out_submitted?
    end

    def from_awaiting_port_out_approval = (:advance_to_sea if port_out_approved?)

    def from_at_sea = (:complete_capture_report if port_in_pending? || port_in_submitted?)

    def from_capture_report_submitted
      return :complete_manifest if complete?

      :begin_port_in_review if port_in_review_ready?
    end

    def from_awaiting_port_in_approval = (:complete_manifest if complete?)

    def from_completed = nil
  end
end
