module Api
  module V1
    module Manifests
      module CaptureReports
        class FishingGearDetailsController < ApplicationController
          before_action :set_capture_report
          before_action :set_fishing_gear_detail, only: %i[show update destroy]

          def index
            authorize FishingGearDetail
            render json: { status: "success",
                           data: FishingGearDetailBlueprint.render_as_hash(@capture_report.fishing_gear_details) }
          end

          def show
            authorize @fishing_gear_detail
            render json: { status: "success", data: FishingGearDetailBlueprint.render_as_hash(@fishing_gear_detail) }
          end

          def create
            authorize FishingGearDetail

            case FishingGearDetails::Create.call(@capture_report, fishing_gear_detail_params)
            in Success(detail)
              render json: { status: "success", data: FishingGearDetailBlueprint.render_as_hash(detail) },
                     status: :created
            in Failure(detail)
              render json: { status: "fail", errors: detail.errors.full_messages }, status: :unprocessable_content
            end
          end

          def update
            authorize @fishing_gear_detail

            case FishingGearDetails::Update.call(@fishing_gear_detail, fishing_gear_detail_params)
            in Success(detail)
              render json: { status: "success", data: FishingGearDetailBlueprint.render_as_hash(detail) }
            in Failure(detail)
              render json: { status: "fail", errors: detail.errors.full_messages }, status: :unprocessable_content
            end
          end

          def destroy
            authorize @fishing_gear_detail

            if @fishing_gear_detail.destroy
              render json: { status: "success", message: "Fishing gear detail removed." }
            else
              render json: { status: "fail", errors: @fishing_gear_detail.errors.full_messages },
                     status: :unprocessable_content
            end
          end

          private

          def set_capture_report
            manifest = policy_scope(::Manifest).find(params.expect(:manifest_id))
            @capture_report = manifest.capture_reports.find(params.expect(:capture_report_id))
          end

          def set_fishing_gear_detail
            @fishing_gear_detail = @capture_report.fishing_gear_details.find(params.expect(:id))
          end

          def fishing_gear_detail_params
            params.expect(fishing_gear_detail: %i[companies_fishing_gear_id quantity])
          end
        end
      end
    end
  end
end
