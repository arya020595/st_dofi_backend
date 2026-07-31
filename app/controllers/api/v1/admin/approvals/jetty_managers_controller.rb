module Api
  module V1
    module Admin
      module Approvals
        class JettyManagersController < ApplicationController
          include RansackSearchable

          before_action :set_jetty_manager, only: %i[show approve reject]

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

            case Users::ApproveRegistration.call(@jetty_manager)
            in Success(user)
              render json: { status: "success", data: JettyManagerApprovalBlueprint.render_as_hash(user) }
            in Failure(user)
              render json: { status: "fail", errors: user.errors.full_messages }, status: :unprocessable_content
            end
          end

          def reject
            authorize @jetty_manager, policy_class: JettyManagerApprovalPolicy

            result = Users::RejectRegistration.call(@jetty_manager,
                                                    approval_remark_id: params.expect(:approval_remark_id))
            case result
            in Success(user)
              render json: { status: "success", data: JettyManagerApprovalBlueprint.render_as_hash(user) }
            in Failure(user)
              render json: { status: "fail", errors: user.errors.full_messages }, status: :unprocessable_content
            end
          end

          private

          def jetty_manager_scope
            policy_scope(User, policy_scope_class: JettyManagerApprovalPolicy::Scope)
          end

          def set_jetty_manager
            @jetty_manager = jetty_manager_scope.find(params.expect(:id))
          end
        end
      end
    end
  end
end
