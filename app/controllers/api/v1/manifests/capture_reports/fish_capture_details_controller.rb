module Api
  module V1
    module Manifests
      module CaptureReports
        class FishCaptureDetailsController < ApplicationController
          before_action :set_capture_report
          before_action :set_fish_capture_detail, only: %i[show update destroy]

          def index
            authorize FishCaptureDetail
            render json: { status: "success",
                           data: FishCaptureDetailBlueprint.render_as_hash(@capture_report.fish_capture_details) }
          end

          def show
            authorize @fish_capture_detail
            render json: { status: "success", data: FishCaptureDetailBlueprint.render_as_hash(@fish_capture_detail) }
          end

          def create
            authorize FishCaptureDetail

            case FishCaptureDetails::Create.call(@capture_report, fish_capture_detail_params)
            in Success(detail)
              render json: { status: "success", data: FishCaptureDetailBlueprint.render_as_hash(detail) },
                     status: :created
            in Failure(detail)
              render json: { status: "fail", errors: detail.errors.full_messages }, status: :unprocessable_content
            end
          end

          def update
            authorize @fish_capture_detail

            case FishCaptureDetails::Update.call(@fish_capture_detail, fish_capture_detail_params)
            in Success(detail)
              render json: { status: "success", data: FishCaptureDetailBlueprint.render_as_hash(detail) }
            in Failure(detail)
              render json: { status: "fail", errors: detail.errors.full_messages }, status: :unprocessable_content
            end
          end

          def destroy
            authorize @fish_capture_detail

            if @fish_capture_detail.destroy
              render json: { status: "success", message: "Fish capture detail removed." }
            else
              render json: { status: "fail", errors: @fish_capture_detail.errors.full_messages },
                     status: :unprocessable_content
            end
          end

          def bulk_sync
            authorize FishCaptureDetail

            result = FishCaptureDetails::BulkSync.call(@capture_report, bulk_sync_params)
            render json: { status: "success", data: FishCaptureSyncResultBlueprint.render_as_hash(result.value!) }
          end

          private

          def set_capture_report
            manifest = policy_scope(::Manifest).find(params.expect(:manifest_id))
            @capture_report = manifest.capture_reports.find(params.expect(:capture_report_id))
          end

          def set_fish_capture_detail
            @fish_capture_detail = @capture_report.fish_capture_details.find(params.expect(:id))
          end

          def fish_capture_detail_params
            params.expect(fish_capture_detail: %i[fishing_gear_detail_id dictionary_id fish_type price_per_kg amount_captured_kg])
          end

          def bulk_sync_params
            params.expect(
              captures: [%i[id fishing_gear_detail_id dictionary_id fish_type price_per_kg amount_captured_kg]]
            )
          end
        end
      end
    end
  end
end
