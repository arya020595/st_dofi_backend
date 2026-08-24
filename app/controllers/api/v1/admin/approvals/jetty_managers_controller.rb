module Api
  module V1
    module Admin
      module Approvals
        class JettyManagersController < ApplicationController
          include RansackSearchable

          before_action :set_jetty_manager, only: %i[show approve reject deactivate reactivate revoke]

          def index
            authorize User, policy_class: JettyManagerApprovalPolicy
            result = apply_ransack_search(jetty_manager_scope, default_sort: "created_at desc")
            pagy, records = pagy(:offset, result)
            render json: { status: "success", data: JettyManagerApprovalBlueprint.render_as_hash(records),
                           meta: pagination_meta(pagy) }
          end

          def show
            authorize @jetty_manager, policy_class: JettyManagerApprovalPolicy
            render json: { status: "success", data: JettyManagerApprovalBlueprint.render_as_hash(@jetty_manager) }
          end

          def approve
            authorize @jetty_manager, policy_class: JettyManagerApprovalPolicy
            render_jetty_manager_result(approve_registration)
          end

          def reject
            authorize @jetty_manager, policy_class: JettyManagerApprovalPolicy
            render_jetty_manager_result(reject_registration)
          end

          def deactivate
            authorize @jetty_manager, policy_class: JettyManagerApprovalPolicy
            render_jetty_manager_result(Users::DeactivateRegistration.call(user: @jetty_manager, actor: current_user,
                                                                           reason: params[:reason]))
          end

          def reactivate
            authorize @jetty_manager, policy_class: JettyManagerApprovalPolicy
            render_jetty_manager_result(Users::ReactivateRegistration.call(user: @jetty_manager, actor: current_user,
                                                                           reason: params[:reason]))
          end

          def revoke
            authorize @jetty_manager, policy_class: JettyManagerApprovalPolicy
            render_jetty_manager_result(Users::RevokeRegistration.call(**revoke_attributes))
          end

          private

          def jetty_manager_scope
            policy_scope(User, policy_scope_class: JettyManagerApprovalPolicy::Scope)
          end

          def set_jetty_manager
            @jetty_manager = jetty_manager_scope.find(params.expect(:id))
          end

          def approve_registration
            Users::ApproveRegistration.call(user: @jetty_manager, actor: current_user, reason: params[:reason])
          end

          def reject_registration
            Users::RejectRegistration.call(@jetty_manager, approval_remark_id: params.expect(:approval_remark_id),
                                                           actor: current_user, reason: params[:reason])
          end

          def revoke_attributes
            {
              user: @jetty_manager,
              actor: current_user,
              approval_remark_id: params.expect(:approval_remark_id),
              reason: params[:reason]
            }
          end

          def render_jetty_manager_result(result)
            case result
            in Success(user)
              render json: { status: "success", data: JettyManagerApprovalBlueprint.render_as_hash(user) }
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
