module MasterData
  module ZonesReadable
    extend ActiveSupport::Concern
    include RansackSearchable

    included do
      before_action :set_zone, only: %i[show]
    end

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

    private

    def set_zone
      @zone = Zone.find(params.expect(:id))
    end
  end
end
