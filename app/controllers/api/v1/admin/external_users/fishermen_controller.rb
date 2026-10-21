module Api
  module V1
    module Admin
      module ExternalUsers
        # User Management → External Users → Fisherman tab: read + deactivate/reactivate only. Fisherman
        # account data itself is created/edited through Company Profiling (contact sync), not here.
        # Shares the external_users.* permission resource with JettyManagersController.
        class FishermenController < ApplicationController
          include RansackSearchable

          before_action :set_fisherman, only: %i[show deactivate reactivate]

          def index
            authorize User, policy_class: ExternalUserPolicy
            result = apply_ransack_search(fishermen, default_sort: "created_at desc")
            pagy, records = pagy(:offset, result)
            render json: { status: "success", data: ExternalUserBlueprint.render_as_hash(records),
                           meta: pagination_meta(pagy) }
          end

          def show
            authorize @fisherman, policy_class: ExternalUserPolicy
            render json: { status: "success", data: ExternalUserBlueprint.render_as_hash(@fisherman) }
          end

          def deactivate
            authorize @fisherman, policy_class: ExternalUserPolicy

            case ::Fisherman::DeactivateUser.call(user: @fisherman, actor: current_user, reason: params[:reason])
            in Success(user)
              render json: { status: "success", data: ExternalUserBlueprint.render_as_hash(user) }
            in Failure(reason)
              render json: { status: "fail", errors: [reason.to_s.humanize] }, status: :unprocessable_content
            end
          end

          def reactivate
            authorize @fisherman, policy_class: ExternalUserPolicy

            case ::Fisherman::ReactivateUser.call(user: @fisherman, actor: current_user, reason: params[:reason])
            in Success(user)
              render json: { status: "success", data: ExternalUserBlueprint.render_as_hash(user) }
            in Failure(reason)
              render json: { status: "fail", errors: [reason.to_s.humanize] }, status: :unprocessable_content
            end
          end

          private

          def fishermen
            policy_scope(User, policy_scope_class: ExternalUserPolicy::FishermanScope)
              .includes(:company_profile, role: :permissions)
          end

          def set_fisherman
            @fisherman = fishermen.find(params.expect(:id))
          end
        end
      end
    end
  end
end
