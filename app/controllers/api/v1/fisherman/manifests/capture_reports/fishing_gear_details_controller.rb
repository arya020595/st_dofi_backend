module Api
  module V1
    module Fisherman
      module Manifests
        module CaptureReports
          class FishingGearDetailsController < ApplicationController
            include ::Manifests::FishingGearDetailsReadable

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
              set_fishing_gear_detail
              authorize @fishing_gear_detail

              case FishingGearDetails::Update.call(@fishing_gear_detail, fishing_gear_detail_params)
              in Success(detail)
                render json: { status: "success", data: FishingGearDetailBlueprint.render_as_hash(detail) }
              in Failure(detail)
                render json: { status: "fail", errors: detail.errors.full_messages }, status: :unprocessable_content
              end
            end

            def destroy
              set_fishing_gear_detail
              authorize @fishing_gear_detail

              if @fishing_gear_detail.destroy
                render json: { status: "success", message: "Fishing gear detail removed." }
              else
                render json: { status: "fail", errors: @fishing_gear_detail.errors.full_messages },
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
