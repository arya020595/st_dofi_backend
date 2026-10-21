module Api
  module V1
    module Admin
      class FishingGearsController < ApplicationController
        include ::MasterData::FishingGearsReadable

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
          set_fishing_gear
          authorize @fishing_gear

          case FishingGears::Update.call(@fishing_gear, fishing_gear_params)
          in Success(gear)
            render json: { status: "success", data: FishingGearBlueprint.render_as_hash(gear) }
          in Failure(gear)
            render json: { status: "fail", errors: gear.errors.full_messages }, status: :unprocessable_content
          end
        end

        def destroy
          set_fishing_gear
          authorize @fishing_gear

          if @fishing_gear.destroy
            render json: { status: "success", message: "Fishing gear removed." }
          else
            render json: { status: "fail", errors: @fishing_gear.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def fishing_gear_params
          params.expect(fishing_gear: %i[local_name name gear_type unit size fee])
        end
      end
    end
  end
end
