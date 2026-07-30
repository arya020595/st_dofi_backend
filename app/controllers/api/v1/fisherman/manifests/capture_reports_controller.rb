module Api
  module V1
    module Fisherman
      module Manifests
        class CaptureReportsController < ApplicationController
          include ::Manifests::CaptureReportsReadable

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
            set_capture_report
            authorize @capture_report

            case ::CaptureReports::Update.call(@capture_report, capture_report_params)
            in Success(report)
              render json: { status: "success", data: CaptureReportDetailBlueprint.render_as_hash(report) }
            in Failure(report)
              render json: { status: "fail", errors: report.errors.full_messages }, status: :unprocessable_content
            end
          end

          def resubmit
            set_capture_report
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
end
