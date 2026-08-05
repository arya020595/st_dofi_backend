module MasterData
  module PositionsReadable
    extend ActiveSupport::Concern
    include RansackSearchable

    included do
      before_action :set_position, only: %i[show]
    end

    def index
      authorize Position
      result = apply_ransack_search(policy_scope(Position), default_sort: "name asc")
      pagy, records = pagy(:offset, result)
      render json: { status: "success", data: PositionBlueprint.render_as_hash(records),
                     meta: pagination_meta(pagy) }
    end

    def show
      authorize @position
      render json: { status: "success", data: PositionBlueprint.render_as_hash(@position) }
    end

    private

    def set_position
      @position = Position.find(params.expect(:id))
    end
  end
end
