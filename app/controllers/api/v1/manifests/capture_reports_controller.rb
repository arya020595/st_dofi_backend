module Api
  module V1
    module Manifests
      class CaptureReportsController < ApplicationController
        before_action :set_manifest
        before_action :set_capture_report, only: %i[show update verify request_amendment resubmit]

        def index
          authorize CaptureReport
          reports = policy_scope(CaptureReport).where(manifest: @manifest)
          render json: { status: "success", data: CaptureReportBlueprint.render_as_hash(reports) }
        end

        def show
          authorize @capture_report
          render json: { status: "success", data: CaptureReportDetailBlueprint.render_as_hash(@capture_report) }
        end

        def create
          authorize CaptureReport

          case ::CaptureReports::Create.call(@manifest, capture_report_params)
          in Success(report)
            render json: { status: "success", data: CaptureReportDetailBlueprint.render_as_hash(report) },
                   status: :created
          in Failure(report)
            render json: { status: "fail", errors: report.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          authorize @capture_report

          case ::CaptureReports::Update.call(@capture_report, capture_report_params)
          in Success(report)
            render json: { status: "success", data: CaptureReportDetailBlueprint.render_as_hash(report) }
          in Failure(report)
            render json: { status: "fail", errors: report.errors.full_messages }, status: :unprocessable_content
          end
        end

        def verify
          authorize @capture_report
          render_transition(::CaptureReports::Verify.call(@capture_report, actor: current_user))
        end

        def request_amendment
          authorize @capture_report
          result = ::CaptureReports::RequestAmendment.call(@capture_report, actor: current_user,
                                                                            remarks: params.expect(:remarks))
          render_transition(result)
        end

        def resubmit
          authorize @capture_report
          render_transition(::CaptureReports::Resubmit.call(@capture_report, actor: current_user))
        end

        private

        def render_transition(result)
          case result
          in Success(report)
            render json: { status: "success", data: CaptureReportDetailBlueprint.render_as_hash(report) }
          in Failure(report)
            render json: { status: "fail", errors: report.errors.full_messages }, status: :unprocessable_content
          end
        end

        def set_manifest
          @manifest = policy_scope(::Manifest).find(params.expect(:manifest_id))
        end

        def set_capture_report
          @capture_report = @manifest.capture_reports.find(params.expect(:id))
        end

        def capture_report_params
          # Every field here is optional on the model (offline-first: the client may create a bare
          # shell record before zone/location is known, then fill it via update or nested resources),
          # so unlike params.expect, an absent/empty capture_report hash must not raise.
          params.fetch(:capture_report, {}).permit(:zone_id, :zone_area, :longitude, :latitude)
        end
      end
    end
  end
end
