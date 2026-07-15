module Api
  module V1
    module CompanyProfiles
      class CaptainsController < ApplicationController
        include RansackSearchable

        before_action :set_company_profile
        before_action :set_captain, only: %i[show update destroy]

        def index
          authorize CompaniesCaptain
          result = apply_ransack_search(policy_scope(@company_profile.companies_captains),
                                        default_sort: "created_at desc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: CompaniesCaptainBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        def show
          authorize @captain
          render json: { status: "success", data: CompaniesCaptainBlueprint.render_as_hash(@captain) }
        end

        def create
          authorize CompaniesCaptain

          case CompaniesCaptains::Create.call(@company_profile, captain_params)
          in Success(captain)
            render json: { status: "success", data: CompaniesCaptainBlueprint.render_as_hash(captain) },
                   status: :created
          in Failure(captain)
            render json: { status: "fail", errors: captain.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          authorize @captain

          case CompaniesCaptains::Update.call(@captain, captain_params)
          in Success(captain)
            render json: { status: "success", data: CompaniesCaptainBlueprint.render_as_hash(captain) }
          in Failure(captain)
            render json: { status: "fail", errors: captain.errors.full_messages }, status: :unprocessable_content
          end
        end

        def destroy
          authorize @captain

          if @captain.discard
            render json: { status: "success", message: "Captain removed." }
          else
            render json: { status: "fail", errors: @captain.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def set_company_profile
          @company_profile = policy_scope(CompanyProfile).find(params.expect(:company_profile_id))
        end

        def set_captain
          @captain = @company_profile.companies_captains.kept.find(params.expect(:id))
        end

        def captain_params
          params.expect(captain: %i[captain_name date_of_birth ic_number passport_number nationality])
        end
      end
    end
  end
end
