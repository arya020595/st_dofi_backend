# Keeps the `*_amendment_remarks` columns equal to the outstanding amendment request (or nil once it is
# resolved), so list/detail responses don't have to query the history table.
module Manifest::AmendmentSnapshots
  extend ActiveSupport::Concern

  def sync_capture_report_amendment_snapshot!
    update!(capture_report_amendment_remarks: latest_capture_report_amendment_remarks)
  end

  def refresh_amendment_snapshots!
    update!(
      port_out_amendment_remarks: latest_manifest_amendment_remarks_for(
        "port_out_status", port_out_amendment_required?
      ),
      port_in_amendment_remarks: latest_manifest_amendment_remarks_for("port_in_status", port_in_amendment_required?),
      capture_report_amendment_remarks: latest_capture_report_amendment_remarks
    )
  end

  private

  def store_port_out_amendment_snapshot!(*, remarks: nil, **)
    update!(port_out_amendment_remarks: remarks)
  end

  def clear_port_out_amendment_snapshot!(*, **)
    update!(port_out_amendment_remarks: nil)
  end

  def store_port_in_amendment_snapshot!(*, remarks: nil, **)
    update!(port_in_amendment_remarks: remarks)
  end

  def clear_port_in_amendment!(*, **)
    update!(port_in_amendment_remarks: nil)
  end

  def clear_capture_report_amendment_snapshot!(*, **)
    update!(capture_report_amendment_remarks: nil)
  end

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
