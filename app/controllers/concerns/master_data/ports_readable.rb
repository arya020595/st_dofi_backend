module MasterData
  module PortsReadable
    extend ActiveSupport::Concern
    include RansackSearchable

    included do
      before_action :set_port, only: %i[show]
    end

    def index
      authorize Port
      result = apply_ransack_search(policy_scope(Port), default_sort: ports_default_sort)
      pagy, records = pagy(:offset, result)
      render json: { status: "success", data: PortBlueprint.render_as_hash(records), meta: pagination_meta(pagy) }
    end

    def show
      authorize @port
      render json: { status: "success", data: PortBlueprint.render_as_hash(@port) }
    end

    private

    def set_port
      @port = Port.find(params.expect(:id))
    end

    # Admin's master-data screen wants newest-added first; Fisherman's picker (selecting a port
    # when building a manifest) wants alphabetical — overridden in Fisherman::PortsController.
    def ports_default_sort
      "created_at desc"
    end
  end
end
