module Api
  module V1
    module Approvals
      class FishingGearsController < ApplicationController
        include RansackSearchable

        before_action :set_fishing_gear, only: %i[show approve request_amendment]

        def index
          authorize CompaniesFishingGear, policy_class: CompaniesFishingGearApprovalPolicy
          result = apply_ransack_search(fishing_gear_scope, default_sort: "created_at desc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: CompaniesFishingGearApprovalBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        def show
          authorize @fishing_gear, policy_class: CompaniesFishingGearApprovalPolicy
          render json: { status: "success", data: CompaniesFishingGearApprovalBlueprint.render_as_hash(@fishing_gear) }
        end

        def approve
          authorize @fishing_gear, policy_class: CompaniesFishingGearApprovalPolicy

          case CompaniesFishingGears::Approve.call(@fishing_gear, actor: current_user)
          in Success(gear)
            render json: { status: "success", data: CompaniesFishingGearApprovalBlueprint.render_as_hash(gear) }
          in Failure(gear)
            render json: { status: "fail", errors: gear.errors.full_messages }, status: :unprocessable_content
          end
        end

        def request_amendment
          authorize @fishing_gear, policy_class: CompaniesFishingGearApprovalPolicy

          result = CompaniesFishingGears::RequestAmendment.call(@fishing_gear, actor: current_user,
                                                                               remarks: params.expect(:remarks))
          case result
          in Success(gear)
            render json: { status: "success", data: CompaniesFishingGearApprovalBlueprint.render_as_hash(gear) }
          in Failure(gear)
            render json: { status: "fail", errors: gear.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def fishing_gear_scope
          policy_scope(CompaniesFishingGear, policy_scope_class: CompaniesFishingGearApprovalPolicy::Scope)
        end

        def set_fishing_gear
          @fishing_gear = fishing_gear_scope.find(params.expect(:id))
        end
      end
    end
  end
end
