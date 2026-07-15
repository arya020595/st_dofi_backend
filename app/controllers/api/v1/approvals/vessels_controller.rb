module Api
  module V1
    module Approvals
      class VesselsController < ApplicationController
        include RansackSearchable

        before_action :set_vessel, only: %i[show approve request_amendment]

        def index
          authorize CompaniesVessel, policy_class: CompaniesVesselApprovalPolicy
          result = apply_ransack_search(vessel_scope, default_sort: "created_at desc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: CompaniesVesselApprovalBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        def show
          authorize @vessel, policy_class: CompaniesVesselApprovalPolicy
          render json: { status: "success", data: CompaniesVesselApprovalBlueprint.render_as_hash(@vessel) }
        end

        def approve
          authorize @vessel, policy_class: CompaniesVesselApprovalPolicy

          case CompaniesVessels::Approve.call(@vessel, actor: current_user)
          in Success(vessel)
            render json: { status: "success", data: CompaniesVesselApprovalBlueprint.render_as_hash(vessel) }
          in Failure(vessel)
            render json: { status: "fail", errors: vessel.errors.full_messages }, status: :unprocessable_content
          end
        end

        def request_amendment
          authorize @vessel, policy_class: CompaniesVesselApprovalPolicy

          result = CompaniesVessels::RequestAmendment.call(@vessel, actor: current_user,
                                                                    remarks: params.expect(:remarks))
          case result
          in Success(vessel)
            render json: { status: "success", data: CompaniesVesselApprovalBlueprint.render_as_hash(vessel) }
          in Failure(vessel)
            render json: { status: "fail", errors: vessel.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def vessel_scope
          policy_scope(CompaniesVessel, policy_scope_class: CompaniesVesselApprovalPolicy::Scope)
        end

        def set_vessel
          @vessel = vessel_scope.find(params.expect(:id))
        end
      end
    end
  end
end
