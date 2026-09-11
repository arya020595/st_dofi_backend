module Api
  module V1
    module Admin
      class AccountsController < ApplicationController
        include RansackSearchable

        CATEGORIES = %w[fisherman_account jetty_manager_account].freeze
        STATUSES = %w[active inactive].freeze

        before_action :set_account, only: %i[show deactivate reactivate]

        def index
          authorize User, policy_class: AdminAccountPolicy
          return render_invalid_filter unless valid_filters?

          result = apply_ransack_search(filtered_accounts, default_sort: "created_at desc")
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
          render_result(deactivate_account)
        end

        def reactivate
          authorize @account, policy_class: AdminAccountPolicy
          render_result(reactivate_account)
        end

        private

        def set_account
          @account = account_scope.find(params.expect(:id))
        end

        def account_scope
          policy_scope(User, policy_scope_class: AdminAccountPolicy::Scope)
        end

        def filtered_accounts
          accounts = category.blank? ? account_scope : accounts_for_category
          return accounts unless status_filter_present?

          filter_by_status(accounts)
        end

        def accounts_for_category
          return fisherman_accounts if category == "fisherman_account"

          jetty_manager_accounts
        end

        def fisherman_accounts
          account_scope.joins(:role)
                       .where(roles: { platform_scope: Role::FISHERMAN_PLATFORM })
        end

        def jetty_manager_accounts
          account_scope.joins(:role).where(roles: { kind: Role::JETTY_MANAGER })
        end

        def category = params[:category]

        def status_values
          Array(params[:status]).flat_map { |value| value.to_s.split(",") }.compact_blank.uniq
        end

        def status_filter_present? = status_values.any?

        def valid_filters?
          (category.blank? || CATEGORIES.include?(category)) && status_values.all? { |value| STATUSES.include?(value) }
        end

        def filter_by_status(accounts)
          return accounts.where(fisherman_status: fisherman_lifecycle_statuses) if category == "fisherman_account"
          return accounts.where(status: jetty_manager_lifecycle_statuses) if category == "jetty_manager_account"

          accounts.where(
            status_conditions,
            Role::FISHERMAN_PLATFORM,
            fisherman_lifecycle_statuses,
            Role::JETTY_MANAGER,
            jetty_manager_lifecycle_statuses
          )
        end

        def fisherman_lifecycle_statuses
          status_values.map { |value| value == "active" ? "active" : "suspended" }
        end

        def jetty_manager_lifecycle_statuses = status_values

        def status_conditions
          "(roles.platform_scope = ? AND users.fisherman_status IN (?)) OR (roles.kind = ? AND users.status IN (?))"
        end

        def render_invalid_filter
          errors = ["Category must be fisherman_account or jetty_manager_account; status must be active or inactive"]
          render json: { status: "fail", errors: },
                 status: :unprocessable_content
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

        def render_result(result)
          case result
          in Success(user)
            render json: { status: "success", data: AdminAccountBlueprint.render_as_hash(user) }
          in Failure(reason)
            render json: { status: "fail", errors: [reason.to_s.humanize] }, status: :unprocessable_content
          end
        end
      end
    end
  end
end
