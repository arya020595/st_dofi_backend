module Manifests
  module FishingGearDetailsReadable
    extend ActiveSupport::Concern
    include Manifests::CaptureReportScoped

    included do
      before_action :set_fishing_gear_detail, only: %i[show]
    end

    def index
      authorize @capture_report, policy_class: capture_report_policy_class
      render json: { status: "success",
                     data: FishingGearDetailBlueprint.render_as_hash(@capture_report.fishing_gear_details) }
    end

    def show
      authorize @capture_report, policy_class: capture_report_policy_class
      render json: { status: "success", data: FishingGearDetailBlueprint.render_as_hash(@fishing_gear_detail) }
    end

    private

    def set_fishing_gear_detail
      @fishing_gear_detail = @capture_report.fishing_gear_details.find(params.expect(:id))
    end

    def capture_report_policy_class = CaptureReportPolicy
  end
end
