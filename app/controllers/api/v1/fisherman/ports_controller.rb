module Api
  module V1
    module Fisherman
      class PortsController < ApplicationController
        include RansackSearchable

        def index
          authorize Port
          result = apply_ransack_search(policy_scope(Port), default_sort: "port_name asc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: PortBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end
      end
    end
  end
end
