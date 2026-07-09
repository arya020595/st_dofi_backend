module Api
  module V1
    module MasterData
      class PositionsController < ApplicationController
        include RansackSearchable

        before_action :set_position, only: %i[show update destroy]

        def index
          authorize Position
          result = apply_ransack_search(policy_scope(Position), default_sort: "created_at desc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: PositionBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        def show
          authorize @position
          render json: { status: "success", data: PositionBlueprint.render_as_hash(@position) }
        end

        def create
          authorize Position

          case Positions::Create.call(position_params)
          in Success(position)
            render json: { status: "success", data: PositionBlueprint.render_as_hash(position) }, status: :created
          in Failure(position)
            render json: { status: "fail", errors: position.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          authorize @position

          case Positions::Update.call(@position, position_params)
          in Success(position)
            render json: { status: "success", data: PositionBlueprint.render_as_hash(position) }
          in Failure(position)
            render json: { status: "fail", errors: position.errors.full_messages }, status: :unprocessable_content
          end
        end

        def destroy
          authorize @position

          if @position.destroy
            render json: { status: "success", message: "Position removed." }
          else
            render json: { status: "fail", errors: @position.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def set_position
          @position = Position.find(params.expect(:id))
        end

        def position_params
          params.expect(position: %i[name category])
        end
      end
    end
  end
end
