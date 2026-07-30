module Api
  module V1
    module Admin
      module Approvals
        class CaptainsController < ApplicationController
          include RansackSearchable

          before_action :set_captain, only: %i[show approve request_amendment]

          def index
            authorize CompaniesCaptain, policy_class: CompaniesCaptainApprovalPolicy
            result = apply_ransack_search(captain_scope, default_sort: "created_at desc")
            pagy, records = pagy(:offset, result)
            render json: { status: "success", data: CompaniesCaptainApprovalBlueprint.render_as_hash(records),
                           meta: pagination_meta(pagy) }
          end

          def show
            authorize @captain, policy_class: CompaniesCaptainApprovalPolicy
            render json: { status: "success", data: CompaniesCaptainApprovalBlueprint.render_as_hash(@captain) }
          end

          def approve
            authorize @captain, policy_class: CompaniesCaptainApprovalPolicy

            case CompaniesCaptains::Approve.call(@captain, actor: current_user)
            in Success(captain)
              render json: { status: "success", data: CompaniesCaptainApprovalBlueprint.render_as_hash(captain) }
            in Failure(captain)
              render json: { status: "fail", errors: captain.errors.full_messages }, status: :unprocessable_content
            end
          end

          def request_amendment
            authorize @captain, policy_class: CompaniesCaptainApprovalPolicy

            result = CompaniesCaptains::RequestAmendment.call(@captain, actor: current_user,
                                                                        remarks: params.expect(:remarks))
            case result
            in Success(captain)
              render json: { status: "success", data: CompaniesCaptainApprovalBlueprint.render_as_hash(captain) }
            in Failure(captain)
              render json: { status: "fail", errors: captain.errors.full_messages }, status: :unprocessable_content
            end
          end

          private

          def captain_scope
            policy_scope(CompaniesCaptain, policy_scope_class: CompaniesCaptainApprovalPolicy::Scope)
          end

          def set_captain
            @captain = captain_scope.find(params.expect(:id))
          end
        end
      end
    end
  end
end
