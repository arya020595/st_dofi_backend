module MasterData
  module FishingGearsReadable
    extend ActiveSupport::Concern
    include RansackSearchable

    included do
      before_action :set_fishing_gear, only: %i[show]
    end

    def index
      authorize FishingGear if reference_data_permission_required?
      result = apply_ransack_search(reference_data_scope(FishingGear), default_sort: "created_at desc")
      pagy, records = pagy(:offset, result)
      render json: { status: "success", data: FishingGearBlueprint.render_as_hash(records),
                     meta: pagination_meta(pagy) }
    end

    def show
      authorize @fishing_gear if reference_data_permission_required?
      render json: { status: "success", data: FishingGearBlueprint.render_as_hash(@fishing_gear) }
    end

    private

    def set_fishing_gear
      @fishing_gear = FishingGear.find(params.expect(:id))
    end

    def reference_data_scope(model)
      return model.all unless reference_data_permission_required?

      policy_scope(model)
    end

    def reference_data_permission_required? = true
  end
end
