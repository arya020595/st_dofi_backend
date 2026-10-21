module Api
  module V1
    module Admin
      module Manifests
        module CaptureReports
          class FishCaptureDetailsController < ApplicationController
            before_action :set_manifest
            before_action :set_capture_report
            before_action :set_fish_capture_detail, only: %i[show]

            def index
              authorize @capture_report, policy_class: CaptureReportVerificationPolicy
              render json: { status: "success",
                             data: FishCaptureDetailBlueprint.render_as_hash(@capture_report.fish_capture_details) }
            end

            def show
              authorize @capture_report, policy_class: CaptureReportVerificationPolicy
              render json: { status: "success", data: FishCaptureDetailBlueprint.render_as_hash(@fish_capture_detail) }
            end

            private

            def set_manifest
              @manifest = policy_scope(Manifest, policy_scope_class: ManifestApprovalPolicy::Scope)
                          .find(params.expect(:manifest_id))
            end

            def set_capture_report
              @capture_report = policy_scope(CaptureReport, policy_scope_class: CaptureReportVerificationPolicy::Scope)
                                .where(manifest: @manifest).find(params.expect(:capture_report_id))
            end

            def set_fish_capture_detail
              @fish_capture_detail = @capture_report.fish_capture_details.find(params.expect(:id))
            end
          end
        end
      end
    end
  end
end
