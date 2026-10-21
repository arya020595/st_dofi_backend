module MasterData
  module ReasonsReadable
    extend ActiveSupport::Concern
    include RansackSearchable

    included do
      before_action :set_reason, only: %i[show]
    end

    def index
      authorize ManifestSkipReason
      result = apply_ransack_search(policy_scope(ManifestSkipReason), default_sort: "name asc")
      pagy, records = pagy(:offset, result)
      render json: { status: "success", data: ManifestSkipReasonBlueprint.render_as_hash(records),
                     meta: pagination_meta(pagy) }
    end

    def show
      authorize @reason
      render json: { status: "success", data: ManifestSkipReasonBlueprint.render_as_hash(@reason) }
    end

    private

    def set_reason
      @reason = ManifestSkipReason.find(params.expect(:id))
    end
  end
end
