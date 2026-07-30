module Manifests
  module CaptureReportsReadable
    extend ActiveSupport::Concern
    include Manifests::ManifestScoped

    included do
      before_action :set_capture_report, only: %i[show]
    end

    def index
      authorize CaptureReport
      reports = policy_scope(CaptureReport).where(manifest: @manifest)
      render json: { status: "success", data: CaptureReportBlueprint.render_as_hash(reports) }
    end

    def show
      authorize @capture_report
      render json: { status: "success", data: CaptureReportDetailBlueprint.render_as_hash(@capture_report) }
    end

    private

    def set_capture_report
      @capture_report = @manifest.capture_reports.find(params.expect(:id))
    end
  end
end
