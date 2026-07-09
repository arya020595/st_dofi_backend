module Api
  module V1
    module Approvals
      class FishermenController < ApplicationController
        include RansackSearchable

        before_action :set_fisherman, only: %i[show approve reject]

        def index
          authorize User, policy_class: FishermanApprovalPolicy
          result = apply_ransack_search(fisherman_scope, default_sort: "created_at desc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: FishermanApprovalBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        def show
          authorize @fisherman, policy_class: FishermanApprovalPolicy
          render json: { status: "success", data: FishermanApprovalDetailBlueprint.render_as_hash(@fisherman) }
        end

        def approve
          authorize @fisherman, policy_class: FishermanApprovalPolicy

          case Users::ApproveRegistration.call(@fisherman)
          in Success(user)
            render json: { status: "success", data: FishermanApprovalBlueprint.render_as_hash(user) }
          in Failure(user)
            render json: { status: "fail", errors: user.errors.full_messages }, status: :unprocessable_content
          end
        end

        def reject
          authorize @fisherman, policy_class: FishermanApprovalPolicy

          result = Users::RejectRegistration.call(@fisherman, approval_remark_id: params.expect(:approval_remark_id))
          case result
          in Success(user)
            render json: { status: "success", data: FishermanApprovalBlueprint.render_as_hash(user) }
          in Failure(user)
            render json: { status: "fail", errors: user.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def fisherman_scope
          policy_scope(User, policy_scope_class: FishermanApprovalPolicy::Scope)
        end

        def set_fisherman
          @fisherman = fisherman_scope.find(params.expect(:id))
        end
      end
    end
  end
end
