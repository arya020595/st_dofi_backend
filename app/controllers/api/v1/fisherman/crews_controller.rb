module Api
  module V1
    module Fisherman
      class CrewsController < ApplicationController
        include RansackSearchable

        def index
          authorize CompanyProfile
          result = apply_ransack_search(manifest_crews, default_sort: "crew_name asc")
          pagy, records = pagy(:offset, result)

          render json: { status: "success", data: CompaniesCrewBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        private

        def manifest_crews
          policy_scope(CompanyProfile).companies_crews.kept.where(approval_status: "approved")
        end
      end
    end
  end
end
