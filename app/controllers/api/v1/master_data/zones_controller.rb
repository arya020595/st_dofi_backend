module Api
  module V1
    module MasterData
      class ZonesController < ApplicationController
        include RansackSearchable

        before_action :set_zone, only: %i[show update destroy]

        def index
          authorize Zone
          result = apply_ransack_search(policy_scope(Zone), default_sort: "name asc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: ZoneBlueprint.render_as_hash(records), meta: pagination_meta(pagy) }
        end

        def show
          authorize @zone
          render json: { status: "success", data: ZoneBlueprint.render_as_hash(@zone) }
        end

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
          authorize @zone

          case Zones::Update.call(@zone, zone_params)
          in Success(zone)
            render json: { status: "success", data: ZoneBlueprint.render_as_hash(zone) }
          in Failure(zone)
            render json: { status: "fail", errors: zone.errors.full_messages }, status: :unprocessable_content
          end
        end

        def destroy
          authorize @zone

          if @zone.destroy
            render json: { status: "success", message: "Zone removed." }
          else
            render json: { status: "fail", errors: @zone.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def set_zone
          @zone = Zone.find(params.expect(:id))
        end

        def zone_params
          params.expect(zone: %i[name zone_type start_range end_range])
        end
      end
    end
  end
end
