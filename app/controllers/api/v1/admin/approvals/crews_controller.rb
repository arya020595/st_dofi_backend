module Api
  module V1
    module Admin
      module Approvals
        class CrewsController < ApplicationController
          include RansackSearchable

          before_action :set_crew, only: %i[show approve request_amendment]

          def index
            authorize CompaniesCrew, policy_class: CompaniesCrewApprovalPolicy
            result = apply_ransack_search(crew_scope, default_sort: "created_at desc")
            pagy, records = pagy(:offset, result)
            render json: { status: "success", data: CompaniesCrewApprovalBlueprint.render_as_hash(records),
                           meta: pagination_meta(pagy) }
          end

          def show
            authorize @crew, policy_class: CompaniesCrewApprovalPolicy
            render json: { status: "success", data: CompaniesCrewApprovalBlueprint.render_as_hash(@crew) }
          end

          def approve
            authorize @crew, policy_class: CompaniesCrewApprovalPolicy

            case CompaniesCrews::Approve.call(@crew, actor: current_user)
            in Success(crew)
              render json: { status: "success", data: CompaniesCrewApprovalBlueprint.render_as_hash(crew) }
            in Failure(crew)
              render json: { status: "fail", errors: crew.errors.full_messages }, status: :unprocessable_content
            end
          end

          def request_amendment
            authorize @crew, policy_class: CompaniesCrewApprovalPolicy

            result = CompaniesCrews::RequestAmendment.call(@crew, actor: current_user, remarks: params.expect(:remarks))
            case result
            in Success(crew)
              render json: { status: "success", data: CompaniesCrewApprovalBlueprint.render_as_hash(crew) }
            in Failure(crew)
              render json: { status: "fail", errors: crew.errors.full_messages }, status: :unprocessable_content
            end
          end

          private

          def crew_scope
            policy_scope(CompaniesCrew, policy_scope_class: CompaniesCrewApprovalPolicy::Scope)
          end

          def set_crew
            @crew = crew_scope.find(params.expect(:id))
          end
        end
      end
    end
  end
end
