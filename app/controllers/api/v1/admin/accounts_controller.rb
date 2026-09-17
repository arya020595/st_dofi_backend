module Api
  module V1
    module Admin
      class AccountsController < ApplicationController
        include RansackSearchable

        before_action :set_account, only: %i[show deactivate reactivate]

        def index
          authorize User, policy_class: AdminAccountPolicy
          result = apply_ransack_search(account_scope, default_sort: "created_at desc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: AdminAccountBlueprint.render_as_hash(records),
                         meta: pagination_meta(pagy) }
        end

        def show
          authorize @account, policy_class: AdminAccountPolicy
          render json: { status: "success", data: AdminAccountBlueprint.render_as_hash(@account) }
        end

        def deactivate
          authorize @account, policy_class: AdminAccountPolicy
          case deactivate_account
          in Success(user)
            render json: { status: "success", data: AdminAccountBlueprint.render_as_hash(user) }
          in Failure(reason)
            render json: { status: "fail", errors: [reason.to_s.humanize] }, status: :unprocessable_content
          end
        end

        def reactivate
          authorize @account, policy_class: AdminAccountPolicy
          case reactivate_account
          in Success(user)
            render json: { status: "success", data: AdminAccountBlueprint.render_as_hash(user) }
          in Failure(reason)
            render json: { status: "fail", errors: [reason.to_s.humanize] }, status: :unprocessable_content
          end
        end

        private

        def set_account
          @account = account_scope.find(params.expect(:id))
        end

        def account_scope
          policy_scope(User, policy_scope_class: AdminAccountPolicy::Scope)
        end

        def deactivate_account
          if @account.fisherman?
            ::Fisherman::DeactivateUser.call(user: @account, actor: current_user, reason: params[:reason])
          else
            Users::DeactivateRegistration.call(user: @account, actor: current_user, reason: params[:reason])
          end
        end

        def reactivate_account
          if @account.fisherman?
            ::Fisherman::ReactivateUser.call(user: @account, actor: current_user, reason: params[:reason])
          else
            Users::ReactivateRegistration.call(user: @account, actor: current_user, reason: params[:reason])
          end
        end
      end
    end
  end
end
