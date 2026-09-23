module Api
  module V1
    module Admin
      module ExternalUsers
        # User Management → External Users → Jetty Manager tab. Shares the one external_users.*
        # permission resource (ExternalUserPolicy) with the Fisherman tab (FishermenController); the
        # two are split because their lifecycle (users.status vs fisherman_status) and workflow (full
        # CRUD here vs read + lifecycle only there) differ, not their permissions.
        class JettyManagersController < ApplicationController
          include RansackSearchable

          before_action :set_jetty_manager, only: %i[show update destroy deactivate reactivate]

          def index
            authorize User, policy_class: ExternalUserPolicy
            result = apply_ransack_search(jetty_managers, default_sort: "created_at desc")
            pagy, records = pagy(:offset, result)
            render json: { status: "success", data: ExternalUserBlueprint.render_as_hash(records),
                           meta: pagination_meta(pagy) }
          end

          def show
            authorize @jetty_manager, policy_class: ExternalUserPolicy
            render json: { status: "success", data: ExternalUserBlueprint.render_as_hash(@jetty_manager) }
          end

          def create
            authorize User, policy_class: ExternalUserPolicy

            case Users::CreateJettyManager.call(jetty_manager_params, actor: current_user)
            in Success(user)
              render json: { status: "success", data: ExternalUserBlueprint.render_as_hash(user) }, status: :created
            in Failure(user)
              render json: { status: "fail", errors: user.errors.full_messages }, status: :unprocessable_content
            end
          end

          def update
            authorize @jetty_manager, policy_class: ExternalUserPolicy

            if @jetty_manager.update(jetty_manager_params)
              render json: { status: "success", data: ExternalUserBlueprint.render_as_hash(@jetty_manager) }
            else
              render json: { status: "fail", errors: @jetty_manager.errors.full_messages },
                     status: :unprocessable_content
            end
          end

          def destroy
            authorize @jetty_manager, policy_class: ExternalUserPolicy

            if @jetty_manager.discard
              render json: { status: "success", message: "Jetty Manager removed." }
            else
              render json: { status: "fail", errors: @jetty_manager.errors.full_messages },
                     status: :unprocessable_content
            end
          end

          def deactivate
            authorize @jetty_manager, policy_class: ExternalUserPolicy

            case Users::DeactivateRegistration.call(user: @jetty_manager, actor: current_user, reason: params[:reason])
            in Success(user)
              render json: { status: "success", data: ExternalUserBlueprint.render_as_hash(user) }
            in Failure(reason)
              render json: { status: "fail", errors: [reason.to_s.humanize] }, status: :unprocessable_content
            end
          end

          def reactivate
            authorize @jetty_manager, policy_class: ExternalUserPolicy

            case Users::ReactivateRegistration.call(user: @jetty_manager, actor: current_user, reason: params[:reason])
            in Success(user)
              render json: { status: "success", data: ExternalUserBlueprint.render_as_hash(user) }
            in Failure(reason)
              render json: { status: "fail", errors: [reason.to_s.humanize] }, status: :unprocessable_content
            end
          end

          private

          def jetty_managers
            policy_scope(User, policy_scope_class: ExternalUserPolicy::JettyManagerScope)
              .includes(:company_profile, role: :permissions)
          end

          def set_jetty_manager
            @jetty_manager = jetty_managers.find(params.expect(:id))
          end

          def jetty_manager_params
            params.expect(jetty_manager: %i[name ic_number unit position contact_no])
          end
        end
      end
    end
  end
end
