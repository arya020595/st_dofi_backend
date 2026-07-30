module Manifests
  module FishCaptureDetailsReadable
    extend ActiveSupport::Concern
    include Manifests::CaptureReportScoped

    included do
      before_action :set_fish_capture_detail, only: %i[show]
    end

    def index
      authorize FishCaptureDetail
      render json: { status: "success",
                     data: FishCaptureDetailBlueprint.render_as_hash(@capture_report.fish_capture_details) }
    end

    def show
      authorize @fish_capture_detail
      render json: { status: "success", data: FishCaptureDetailBlueprint.render_as_hash(@fish_capture_detail) }
    end

    private

    def set_fish_capture_detail
      @fish_capture_detail = @capture_report.fish_capture_details.find(params.expect(:id))
    end
  end
end
