# The `*_amendment_remarks` columns hold the outstanding amendment request (nil once it is resolved), so list and
# detail responses don't have to query the history table. The Port-Out / Port-In services write their own column when
# they fire the event; the Capture Report one is derived from the reports, so it is recomputed here.
module Manifest::AmendmentSnapshots
  extend ActiveSupport::Concern

  def sync_capture_report_amendment_snapshot!
    update!(capture_report_amendment_remarks: latest_capture_report_amendment_remarks)
  end

  # Rebuilds all three from the data of record; for seeds and repairs.
  def refresh_amendment_snapshots!
    update!(
      port_out_amendment_remarks: latest_manifest_amendment_remarks_for("port_out_status",
                                                                        port_out_amendment_required?),
      port_in_amendment_remarks: latest_manifest_amendment_remarks_for("port_in_status", port_in_amendment_required?),
      capture_report_amendment_remarks: latest_capture_report_amendment_remarks
    )
  end

  private

  def latest_manifest_amendment_remarks_for(status_type, active)
    return nil unless active

    manifest_histories.where(status_type: status_type, to_state: "amendment_required")
                      .order(created_at: :desc)
                      .limit(1)
                      .pick(:remarks)
  end

  def latest_capture_report_amendment_remarks
    capture_reports.where(capture_report_status: "needs_amendment")
                   .order(reviewed_at: :desc, updated_at: :desc)
                   .limit(1)
                   .pick(:capture_report_remarks)
  end
end
