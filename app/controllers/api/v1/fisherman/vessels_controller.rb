module Api
  module V1
    module Fisherman
      class VesselsController < ApplicationController
        include RansackSearchable

        def index
          authorize CompaniesVessel
          result = apply_ransack_search(manifest_vessels, default_sort: "vessel_name asc")
          pagy, records = pagy(:offset, result)

          render json: { status: "success", data: CompaniesVesselBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        private

        def manifest_vessels
          policy_scope(CompaniesVessel).where(approval_status: "approved")
        end
      end
    end
  end
end
