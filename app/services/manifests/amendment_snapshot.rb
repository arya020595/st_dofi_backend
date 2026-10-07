module Manifests
  # Keeps the `*_amendment_remarks` columns equal to the outstanding amendment request (nil once resolved), so
  # list and detail responses don't have to query the history table.
  class AmendmentSnapshot
    STORE = { request_amendment_port_out: :port_out_amendment_remarks,
              request_amendment_port_in: :port_in_amendment_remarks }.freeze
    CLEAR = { approve_port_out: :port_out_amendment_remarks, resubmit_port_out: :port_out_amendment_remarks,
              approve_port_in: :port_in_amendment_remarks, resubmit_port_in: :port_in_amendment_remarks }.freeze

    # Called after a Port-Out / Port-In event: store the remarks on a request, clear them once it is resolved.
    def self.apply(manifest, event, remarks: nil)
      if STORE.key?(event)
        manifest.update!(STORE[event] => remarks)
      elsif CLEAR.key?(event)
        manifest.update!(CLEAR[event] => nil)
      end
    end

    def self.sync_capture_report(manifest)
      manifest.update!(capture_report_amendment_remarks: latest_capture_report_remarks(manifest))
    end

    def self.clear_capture_report(manifest)
      manifest.update!(capture_report_amendment_remarks: nil)
    end

    # Rebuilds all three from the data of record; for seeds and repairs.
    def self.refresh(manifest)
      manifest.update!(
        port_out_amendment_remarks: latest_history_remarks(manifest, "port_out_status",
                                                           manifest.port_out_amendment_required?),
        port_in_amendment_remarks: latest_history_remarks(manifest, "port_in_status",
                                                          manifest.port_in_amendment_required?),
        capture_report_amendment_remarks: latest_capture_report_remarks(manifest)
      )
    end

    def self.latest_history_remarks(manifest, status_type, active)
      return nil unless active

      manifest.manifest_histories.where(status_type: status_type, to_state: "amendment_required")
              .order(created_at: :desc).limit(1).pick(:remarks)
    end

    def self.latest_capture_report_remarks(manifest)
      manifest.capture_reports.where(capture_report_status: "needs_amendment")
              .order(reviewed_at: :desc, updated_at: :desc).limit(1).pick(:capture_report_remarks)
    end
    private_class_method :latest_history_remarks, :latest_capture_report_remarks
  end
end
