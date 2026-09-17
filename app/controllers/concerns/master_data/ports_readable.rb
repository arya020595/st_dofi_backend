module MasterData
  module PortsReadable
    extend ActiveSupport::Concern
    include RansackSearchable

    included do
      before_action :set_port, only: %i[show]
    end

    def index
      authorize Port if reference_data_permission_required?
      result = apply_ransack_search(reference_data_scope(Port), default_sort: ports_default_sort)
      pagy, records = pagy(:offset, result)
      render json: { status: "success", data: PortBlueprint.render_as_hash(records), meta: pagination_meta(pagy) }
    end

    def show
      authorize @port if reference_data_permission_required?
      render json: { status: "success", data: PortBlueprint.render_as_hash(@port) }
    end

    private

    def set_port
      @port = Port.find(params.expect(:id))
    end

    def reference_data_scope(model)
      return model.all unless reference_data_permission_required?

      policy_scope(model)
    end

    def reference_data_permission_required? = true

    # Admin's master-data screen wants newest-added first; Fisherman's picker (selecting a port
    # when building a manifest) wants alphabetical — overridden in Fisherman::PortsController.
    def ports_default_sort
      "created_at desc"
    end
  end
end
