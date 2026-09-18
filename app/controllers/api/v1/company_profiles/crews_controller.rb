module Api
  module V1
    module CompanyProfiles
      class CrewsController < ApplicationController
        include RansackSearchable

        before_action :set_company_profile
        before_action :set_crew, only: %i[show update destroy]

        def index
          authorize @company_profile
          result = apply_ransack_search(@company_profile.companies_crews.kept, default_sort: "created_at desc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: CompaniesCrewBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        def show
          authorize @company_profile
          render json: { status: "success", data: CompaniesCrewBlueprint.render_as_hash(@crew) }
        end

        def create
          authorize @company_profile

          case CompaniesCrews::Create.call(@company_profile, crew_params)
          in Success(crew)
            render json: { status: "success", data: CompaniesCrewBlueprint.render_as_hash(crew) }, status: :created
          in Failure(crew)
            render json: { status: "fail", errors: crew.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          authorize @company_profile

          case CompaniesCrews::Update.call(@crew, crew_params)
          in Success(crew)
            render json: { status: "success", data: CompaniesCrewBlueprint.render_as_hash(crew) }
          in Failure(crew)
            render json: { status: "fail", errors: crew.errors.full_messages }, status: :unprocessable_content
          end
        end

        def destroy
          authorize @company_profile

          if @crew.discard
            render json: { status: "success", message: "Crew removed." }
          else
            render json: { status: "fail", errors: @crew.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def set_company_profile
          @company_profile = policy_scope(CompanyProfile).find(params.expect(:company_profile_id))
        end

        def set_crew
          @crew = @company_profile.companies_crews.kept.find(params.expect(:id))
        end

        def crew_params
          params.expect(crew: %i[crew_name date_of_birth ic_number passport_number position_id nationality gender
                                 status foreign_worker_license_no foreign_worker_license_start_date
                                 foreign_worker_license_end_date])
        end
      end
    end
  end
end
