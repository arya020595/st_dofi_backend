module Api
  module V1
    module CompanyProfiles
      class CrewsController < ApplicationController
        include RansackSearchable

        before_action :set_company_profile
        before_action :set_crew, only: %i[show update destroy]

        def index
          authorize CompaniesCrew
          result = apply_ransack_search(policy_scope(@company_profile.companies_crews), default_sort: "created_at desc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: CompaniesCrewBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        def show
          authorize @crew
          render json: { status: "success", data: CompaniesCrewBlueprint.render_as_hash(@crew) }
        end

        def create
          authorize CompaniesCrew

          case CompaniesCrews::Create.call(@company_profile, crew_params)
          in Success(crew)
            render json: { status: "success", data: CompaniesCrewBlueprint.render_as_hash(crew) }, status: :created
          in Failure(crew)
            render json: { status: "fail", errors: crew.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          authorize @crew

          case CompaniesCrews::Update.call(@crew, crew_params)
          in Success(crew)
            render json: { status: "success", data: CompaniesCrewBlueprint.render_as_hash(crew) }
          in Failure(crew)
            render json: { status: "fail", errors: crew.errors.full_messages }, status: :unprocessable_content
          end
        end

        def destroy
          authorize @crew

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
          params.expect(crew: %i[crew_name date_of_birth ic_number passport_number position nationality])
        end
      end
    end
  end
end
