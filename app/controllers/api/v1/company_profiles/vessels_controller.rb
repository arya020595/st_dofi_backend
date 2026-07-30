module Api
  module V1
    module CompanyProfiles
      class VesselsController < ApplicationController
        include RansackSearchable

        before_action :set_company_profile
        before_action :set_vessel, only: %i[show update destroy images]

        def index
          authorize CompaniesVessel
          scope = policy_scope(@company_profile.companies_vessels).includes(images_attachments: :blob)
          result = apply_ransack_search(scope, default_sort: "created_at desc")
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

        def images
          authorize @vessel, :update?

          case CompaniesVessels::AttachImages.call(@vessel, image_params)
          in Success(vessel)
            render json: { status: "success", data: CompaniesVesselBlueprint.render_as_hash(vessel) }
          in Failure(vessel)
            render json: { status: "fail", errors: vessel.errors.full_messages }, status: :unprocessable_content
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
          params.expect(vessel: %i[vessel_name boat_number capacity license_reg_date license_expiry_date
                                   status category zone_id registration_no max_crew gross_tonnage
                                   length horse_power year_built draft material
                                   is_powered charter_type boat_type engine_count])
        end

        def image_params
          params.expect(images: [])
        end
      end
    end
  end
end
