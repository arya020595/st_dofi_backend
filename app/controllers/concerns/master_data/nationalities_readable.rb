module MasterData
  module NationalitiesReadable
    extend ActiveSupport::Concern
    include RansackSearchable

    included do
      before_action :set_nationality, only: %i[show]
    end

    def index
      authorize Nationality if reference_data_permission_required?
      result = apply_ransack_search(reference_data_scope(Nationality), default_sort: "name asc")
      pagy, records = pagy(:offset, result)
      render json: { status: "success", data: NationalityBlueprint.render_as_hash(records),
                     meta: pagination_meta(pagy) }
    end

    def show
      authorize @nationality if reference_data_permission_required?
      render json: { status: "success", data: NationalityBlueprint.render_as_hash(@nationality) }
    end

    private

    def set_nationality
      @nationality = Nationality.find(params.expect(:id))
    end

    def reference_data_scope(model)
      return model.all unless reference_data_permission_required?

      policy_scope(model)
    end

    def reference_data_permission_required? = true
  end
end
