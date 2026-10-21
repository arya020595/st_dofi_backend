module Api
  module V1
    module Fisherman
      module Manifests
        module CaptureReports
          class FishingGearDetailsController < ApplicationController
            include ::Manifests::FishingGearDetailsReadable

            def create
              authorize FishingGearDetail, policy_class: CaptureReportPolicy

              case FishingGearDetails::Create.call(@capture_report, fishing_gear_detail_params)
              in Success(detail)
                render json: { status: "success", data: FishingGearDetailBlueprint.render_as_hash(detail) },
                       status: :created
              in Failure(detail)
                render json: { status: "fail", errors: detail.errors.full_messages }, status: :unprocessable_content
              end
            end

            def update
              set_fishing_gear_detail
              authorize @fishing_gear_detail, policy_class: CaptureReportPolicy

              case FishingGearDetails::Update.call(@fishing_gear_detail, fishing_gear_detail_params)
              in Success(detail)
                render json: { status: "success", data: FishingGearDetailBlueprint.render_as_hash(detail) }
              in Failure(detail)
                render json: { status: "fail", errors: detail.errors.full_messages }, status: :unprocessable_content
              end
            end

            def destroy
              set_fishing_gear_detail
              authorize @fishing_gear_detail, policy_class: CaptureReportPolicy

              case FishingGearDetails::Destroy.call(@fishing_gear_detail)
              in Success(detail)
                render json: { status: "success", message: "Fishing gear detail removed." }
              in Failure(detail)
                render json: { status: "fail", errors: detail.errors.full_messages },
                       status: :unprocessable_content
              end
            end

            private

            def fishing_gear_detail_params
              params.expect(fishing_gear_detail: %i[companies_fishing_gear_id quantity])
            end
          end
        end
      end
    end
  end
end
