module Api
  module V1
    module Admin
      module Manifests
        class CaptureReportsController < ApplicationController
          include ::Manifests::ManifestScoped

          before_action :set_capture_report, only: %i[show verify request_amendment]

          def index
            authorize CaptureReport, policy_class: CaptureReportVerificationPolicy
            reports = capture_report_verification_scope.where(manifest: @manifest)
            render json: { status: "success", data: CaptureReportBlueprint.render_as_hash(reports) }
          end

          def show
            authorize @capture_report, policy_class: CaptureReportVerificationPolicy
            render json: { status: "success", data: CaptureReportDetailBlueprint.render_as_hash(@capture_report) }
          end

          def verify
            authorize @capture_report, policy_class: CaptureReportVerificationPolicy
            render_transition(::CaptureReports::Verify.call(@capture_report, actor: current_user))
          end

          def request_amendment
            authorize @capture_report, policy_class: CaptureReportVerificationPolicy
            result = ::CaptureReports::RequestAmendment.call(@capture_report, actor: current_user,
                                                                              remarks: params.expect(:remarks))
            render_transition(result)
          end

          private

          def set_capture_report
            @capture_report = capture_report_verification_scope.where(manifest: @manifest).find(params.expect(:id))
          end

          def capture_report_verification_scope
            policy_scope(CaptureReport, policy_scope_class: CaptureReportVerificationPolicy::Scope)
          end

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
