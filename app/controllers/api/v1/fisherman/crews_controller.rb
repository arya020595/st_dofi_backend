module Api
  module V1
    module Fisherman
      class CrewsController < ApplicationController
        include RansackSearchable

        def index
          authorize Manifest, :create?
          result = apply_ransack_search(manifest_crews, default_sort: "crew_name asc")
          pagy, records = pagy(:offset, result)

          render json: { status: "success", data: CompaniesCrewBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        private

        def manifest_crews
          CompaniesCrew.kept.where(company_profile_id: current_user.company_profile_id, approval_status: "approved")
        end
      end
    end
  end
end
