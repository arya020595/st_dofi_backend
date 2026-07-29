module Api
  module V1
    module Fisherman
      class VesselsController < ApplicationController
        include RansackSearchable

        def index
          authorize Manifest, :create?
          result = apply_ransack_search(manifest_vessels, default_sort: "vessel_name asc")
          pagy, records = pagy(:offset, result)

          render json: { status: "success", data: CompaniesVesselBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        private

        def manifest_vessels
          CompaniesVessel.kept.where(company_profile_id: current_user.company_profile_id, approval_status: "approved")
        end
      end
    end
  end
end
