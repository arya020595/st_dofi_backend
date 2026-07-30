module Api
  module V1
    module Admin
      class ZonesController < ApplicationController
        include ::MasterData::ZonesReadable

        def create
          authorize Zone

          case Zones::Create.call(zone_params)
          in Success(zone)
            render json: { status: "success", data: ZoneBlueprint.render_as_hash(zone) }, status: :created
          in Failure(zone)
            render json: { status: "fail", errors: zone.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          set_zone
          authorize @zone

          case Zones::Update.call(@zone, zone_params)
          in Success(zone)
            render json: { status: "success", data: ZoneBlueprint.render_as_hash(zone) }
          in Failure(zone)
            render json: { status: "fail", errors: zone.errors.full_messages }, status: :unprocessable_content
          end
        end

        def destroy
          set_zone
          authorize @zone

          if @zone.destroy
            render json: { status: "success", message: "Zone removed." }
          else
            render json: { status: "fail", errors: @zone.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def zone_params
          params.expect(zone: %i[name zone_type start_range end_range])
        end
      end
    end
  end
end
