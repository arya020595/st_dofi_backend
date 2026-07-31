module Api
  module V1
    module Admin
      module Manifests
        class CaptureReportsController < ApplicationController
          include ::Manifests::CaptureReportsReadable

          def verify
            set_capture_report
            authorize @capture_report
            render_transition(::CaptureReports::Verify.call(@capture_report, actor: current_user))
          end

          def request_amendment
            set_capture_report
            authorize @capture_report
            result = ::CaptureReports::RequestAmendment.call(@capture_report, actor: current_user,
                                                                              remarks: params.expect(:remarks))
            render_transition(result)
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
        end
      end
    end
  end
end
