module MasterData
  module FishingGearsReadable
    extend ActiveSupport::Concern
    include RansackSearchable

    included do
      before_action :set_fishing_gear, only: %i[show]
    end

    def index
      authorize FishingGear
      result = apply_ransack_search(policy_scope(FishingGear), default_sort: "created_at desc")
      pagy, records = pagy(:offset, result)
      render json: { status: "success", data: FishingGearBlueprint.render_as_hash(records),
                     meta: pagination_meta(pagy) }
    end

    def show
      authorize @fishing_gear
      render json: { status: "success", data: FishingGearBlueprint.render_as_hash(@fishing_gear) }
    end

    private

    def set_fishing_gear
      @fishing_gear = FishingGear.find(params.expect(:id))
    end
  end
end
