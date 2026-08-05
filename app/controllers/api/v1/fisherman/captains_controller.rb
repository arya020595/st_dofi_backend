module Api
  module V1
    module Fisherman
      class CaptainsController < ApplicationController
        include RansackSearchable

        def index
          authorize Manifest, :create?
          result = apply_ransack_search(manifest_captains, default_sort: "crew_name asc")
          pagy, records = pagy(:offset, result)

          render json: { status: "success", data: CompaniesCrewBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        private

        def manifest_captains
          CompaniesCrew.kept.joins(:position)
                       .where(company_profile_id: current_user.company_profile_id, approval_status: "approved")
                       .where(positions: { name: "Boat Captain" })
        end
      end
    end
  end
end
