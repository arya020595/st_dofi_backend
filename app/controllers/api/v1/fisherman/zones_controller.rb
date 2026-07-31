module Api
  module V1
    module Fisherman
      class ZonesController < ApplicationController
        include RansackSearchable

        def index
          authorize Manifest, :create?
          result = apply_ransack_search(policy_scope(Zone), default_sort: "name asc")
          pagy, records = pagy(:offset, result)

          render json: { status: "success", data: ZoneBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end
      end
    end
  end
end
