module Api
  module V1
    module Admin
      module Approvals
        class FishermenController < ApplicationController
          include RansackSearchable

          before_action :set_fisherman, only: %i[show approve reject deactivate reactivate revoke]

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

            case ::Fisherman::ApproveProvisionalUser.call(user: @fisherman, approved_by: current_user,
                                                          reason: params[:reason])
            in Success(user)
              render json: { status: "success", data: FishermanApprovalBlueprint.render_as_hash(user) }
            in Failure(failure)
              render_failure(failure)
            end
          end

          def reject
            authorize @fisherman, policy_class: FishermanApprovalPolicy

            case reject_fisherman
            in Success(user)
              render json: { status: "success", data: FishermanApprovalBlueprint.render_as_hash(user) }
            in Failure(failure)
              render_failure(failure)
            end
          end

          def deactivate
            authorize @fisherman, policy_class: FishermanApprovalPolicy
            render_fisherman_result(::Fisherman::DeactivateUser.call(user: @fisherman, actor: current_user,
                                                                     reason: params[:reason]))
          end

          def reactivate
            authorize @fisherman, policy_class: FishermanApprovalPolicy
            render_fisherman_result(::Fisherman::ReactivateUser.call(user: @fisherman, actor: current_user,
                                                                     reason: params[:reason]))
          end

          def revoke
            authorize @fisherman, policy_class: FishermanApprovalPolicy
            render_fisherman_result(::Fisherman::RevokeUser.call(user: @fisherman, actor: current_user,
                                                                 approval_remark_id: params.expect(:approval_remark_id),
                                                                 reason: params[:reason]))
          end

          private

          def fisherman_scope
            policy_scope(User, policy_scope_class: FishermanApprovalPolicy::Scope)
          end

          def fisherman_lookup_scope
            User.kept.joins(:role).where(roles: { platform_scope: Role::FISHERMAN_PLATFORM })
          end

          def set_fisherman
            @fisherman = fisherman_lookup_scope.find(params.expect(:id))
          end

          def reject_fisherman
            ::Fisherman::RejectProvisionalUser.call(
              user: @fisherman,
              rejected_by: current_user,
              approval_remark_id: params.expect(:approval_remark_id),
              reason: params[:reason]
            )
          end

          def render_fisherman_result(result)
            case result
            in Success(user)
              render json: { status: "success", data: FishermanApprovalBlueprint.render_as_hash(user) }
            in Failure(failure)
              render_failure(failure)
            end
          end

          def render_failure(failure)
            errors = failure.respond_to?(:errors) ? failure.errors.full_messages : [failure.to_s]
            render json: { status: "fail", errors: errors }, status: :unprocessable_content
          end
        end
      end
    end
  end
end
