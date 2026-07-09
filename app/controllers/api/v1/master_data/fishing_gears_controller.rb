module Api
  module V1
    module MasterData
      class FishingGearsController < ApplicationController
        include RansackSearchable

        before_action :set_fishing_gear, only: %i[show update destroy]

        def index
          authorize FishingGear
          result = apply_ransack_search(policy_scope(FishingGear), default_sort: "name asc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: FishingGearBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        def show
          authorize @fishing_gear
          render json: { status: "success", data: FishingGearBlueprint.render_as_hash(@fishing_gear) }
        end

        def create
          authorize FishingGear

          case FishingGears::Create.call(fishing_gear_params)
          in Success(gear)
            render json: { status: "success", data: FishingGearBlueprint.render_as_hash(gear) }, status: :created
          in Failure(gear)
            render json: { status: "fail", errors: gear.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          authorize @fishing_gear

          case FishingGears::Update.call(@fishing_gear, fishing_gear_params)
          in Success(gear)
            render json: { status: "success", data: FishingGearBlueprint.render_as_hash(gear) }
          in Failure(gear)
            render json: { status: "fail", errors: gear.errors.full_messages }, status: :unprocessable_content
          end
        end

        def destroy
          authorize @fishing_gear

          if @fishing_gear.destroy
            render json: { status: "success", message: "Fishing gear removed." }
          else
            render json: { status: "fail", errors: @fishing_gear.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def set_fishing_gear
          @fishing_gear = FishingGear.find(params.expect(:id))
        end

        def fishing_gear_params
          params.expect(fishing_gear: %i[local_name name gear_type unit size fee])
        end
      end
    end
  end
end
