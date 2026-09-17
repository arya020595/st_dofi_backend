module MasterData
  module ZonesReadable
    extend ActiveSupport::Concern
    include RansackSearchable

    included do
      before_action :set_zone, only: %i[show]
    end

    def index
      authorize Zone if reference_data_permission_required?
      result = apply_ransack_search(reference_data_scope(Zone), default_sort: "name asc")
      pagy, records = pagy(:offset, result)
      render json: { status: "success", data: ZoneBlueprint.render_as_hash(records), meta: pagination_meta(pagy) }
    end

    def show
      authorize @zone if reference_data_permission_required?
      render json: { status: "success", data: ZoneBlueprint.render_as_hash(@zone) }
    end

    private

    def set_zone
      @zone = Zone.find(params.expect(:id))
    end

    def reference_data_scope(model)
      return model.all unless reference_data_permission_required?

      policy_scope(model)
    end

    def reference_data_permission_required? = true
  end
end
