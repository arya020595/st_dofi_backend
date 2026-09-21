module Api
  module V1
    module Fisherman
      class VesselsController < ApplicationController
        include RansackSearchable

        def index
          authorize CompaniesVessel, policy_class: CompanyProfilePolicy
          result = apply_ransack_search(manifest_vessels, default_sort: "vessel_name asc")
          pagy, records = pagy(:offset, result)

          render json: { status: "success", data: CompaniesVesselBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        private

        def manifest_vessels
          current_user.company_profile.companies_vessels.kept.where(approval_status: "approved")
        end
      end
    end
  end
end
