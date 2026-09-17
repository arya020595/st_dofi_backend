module MasterData
  module ReasonsReadable
    extend ActiveSupport::Concern
    include RansackSearchable

    included do
      before_action :set_reason, only: %i[show]
    end

    def index
      authorize ManifestSkipReason if reference_data_permission_required?
      result = apply_ransack_search(reference_data_scope(ManifestSkipReason), default_sort: "name asc")
      pagy, records = pagy(:offset, result)
      render json: { status: "success", data: ManifestSkipReasonBlueprint.render_as_hash(records),
                     meta: pagination_meta(pagy) }
    end

    def show
      authorize @reason if reference_data_permission_required?
      render json: { status: "success", data: ManifestSkipReasonBlueprint.render_as_hash(@reason) }
    end

    private

    def set_reason
      @reason = ManifestSkipReason.find(params.expect(:id))
    end

    def reference_data_scope(model)
      return model.all unless reference_data_permission_required?

      policy_scope(model)
    end

    def reference_data_permission_required? = true
  end
end
