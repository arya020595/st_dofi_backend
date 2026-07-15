module Api
  module V1
    module CompanyProfiles
      class VesselsController < ApplicationController
        include RansackSearchable

        before_action :set_company_profile
        before_action :set_vessel, only: %i[show update destroy]

        def index
          authorize CompaniesVessel
          result = apply_ransack_search(policy_scope(@company_profile.companies_vessels),
                                        default_sort: "created_at desc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: CompaniesVesselBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        def show
          authorize @vessel
          render json: { status: "success", data: CompaniesVesselBlueprint.render_as_hash(@vessel) }
        end

        def create
          authorize CompaniesVessel

          case CompaniesVessels::Create.call(@company_profile, vessel_params)
          in Success(vessel)
            render json: { status: "success", data: CompaniesVesselBlueprint.render_as_hash(vessel) }, status: :created
          in Failure(vessel)
            render json: { status: "fail", errors: vessel.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          authorize @vessel

          case CompaniesVessels::Update.call(@vessel, vessel_params)
          in Success(vessel)
            render json: { status: "success", data: CompaniesVesselBlueprint.render_as_hash(vessel) }
          in Failure(vessel)
            render json: { status: "fail", errors: vessel.errors.full_messages }, status: :unprocessable_content
          end
        end

        def destroy
          authorize @vessel

          if @vessel.discard
            render json: { status: "success", message: "Vessel removed." }
          else
            render json: { status: "fail", errors: @vessel.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def set_company_profile
          @company_profile = policy_scope(CompanyProfile).find(params.expect(:company_profile_id))
        end

        def set_vessel
          @vessel = @company_profile.companies_vessels.kept.find(params.expect(:id))
        end

        def vessel_params
          params.expect(vessel: %i[vessel_name boat_number capacity license_reg_date license_expiry_date])
        end
      end
    end
  end
end
