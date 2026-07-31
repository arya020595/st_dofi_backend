module Api
  module V1
    module Fisherman
      class FishingGearsController < ApplicationController
        include RansackSearchable

        def index
          authorize Manifest, :create?
          result = apply_ransack_search(manifest_fishing_gears, default_sort: "created_at asc")
          pagy, records = pagy(:offset, result)

          render json: { status: "success", data: CompaniesFishingGearBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        private

        def manifest_fishing_gears
          scope = CompaniesFishingGear.kept.where(company_profile_id: current_user.company_profile_id,
                                                  approval_status: "approved")
          return scope unless params[:vessel_id].present?

          scope.where(companies_vessel_id: params[:vessel_id])
        end
      end
    end
  end
end
