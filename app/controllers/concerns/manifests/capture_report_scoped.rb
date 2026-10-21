module Manifests
  module CaptureReportScoped
    extend ActiveSupport::Concern
    include Manifests::ManifestScoped

    included do
      before_action :set_capture_report
    end

    private

    def set_capture_report
      @capture_report = @manifest.capture_reports.find(params.expect(:capture_report_id))
    end
  end
end
