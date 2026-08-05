module Api
  module V1
    module CompanyProfiles
      module Vessels
        class FishingGearsController < ApplicationController
          include RansackSearchable

          before_action :set_company_profile
          before_action :set_vessel
          before_action :set_fishing_gear, only: %i[show update destroy]

          def index
            authorize CompaniesFishingGear
            result = apply_ransack_search(policy_scope(@vessel.companies_fishing_gears),
                                          default_sort: "created_at desc")
            pagy, records = pagy(:offset, result)
            render json: { status: "success", data: CompaniesFishingGearBlueprint.render_as_hash(records),
                           meta: pagination_meta(pagy) }
          end

          def show
            authorize @fishing_gear
            render json: { status: "success", data: CompaniesFishingGearBlueprint.render_as_hash(@fishing_gear) }
          end

          def create
            authorize CompaniesFishingGear

            case CompaniesFishingGears::Create.call(@company_profile, @vessel, fishing_gear_params)
            in Success(gear)
              render json: { status: "success", data: CompaniesFishingGearBlueprint.render_as_hash(gear) },
                     status: :created
            in Failure(gear)
              render json: { status: "fail", errors: gear.errors.full_messages }, status: :unprocessable_content
            end
          end

          def update
            authorize @fishing_gear

            case CompaniesFishingGears::Update.call(@fishing_gear, fishing_gear_params)
            in Success(gear)
              render json: { status: "success", data: CompaniesFishingGearBlueprint.render_as_hash(gear) }
            in Failure(gear)
              render json: { status: "fail", errors: gear.errors.full_messages }, status: :unprocessable_content
            end
          end

          def destroy
            authorize @fishing_gear

            if discard_fishing_gear?
              render json: { status: "success", message: "Fishing gear removed." }
            else
              render json: { status: "fail", errors: @fishing_gear.errors.full_messages },
                     status: :unprocessable_content
            end
          end

          private

          def set_company_profile
            @company_profile = policy_scope(CompanyProfile).find(params.expect(:company_profile_id))
          end

          def set_vessel
            @vessel = @company_profile.companies_vessels.kept.find(params.expect(:vessel_id))
          end

          def set_fishing_gear
            @fishing_gear = @vessel.companies_fishing_gears.kept.find(params.expect(:id))
          end

          def fishing_gear_params
            params.expect(fishing_gear: %i[fishing_gear_id local_name quantity usage_value])
          end

          def discard_fishing_gear?
            ActiveRecord::Base.transaction do
              return false unless @fishing_gear.discard

              @vessel.revert_to_pending_for_edit!
            end

            true
          end
        end
      end
    end
  end
end
