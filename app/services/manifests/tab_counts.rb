module Manifests
  class TabCounts
    def self.call(...) = new.call(...)

    def call(scope)
      { port_out: scope.where(manifest_status: %w[draft awaiting_port_out_approval]).count,
        capture_report_and_port_in: scope.where(
          manifest_status: %w[at_sea awaiting_port_in_approval capture_report_submitted]
        ).count,
        complete: scope.where(manifest_status: "completed").count }
    end
  end
end
