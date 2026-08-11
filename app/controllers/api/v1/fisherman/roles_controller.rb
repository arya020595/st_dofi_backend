module Api
  module V1
    module Fisherman
      # Company-scoped mirror of Admin::RolesController. Same controller shape and the same
      # Roles::Create/Update services, but every call forces platform_scope: "fisherman" and this
      # company's own company_profile_id server-side — never accepted as client params (see
      # RolePolicy for the record-level ownership enforcement on show/update/destroy).
      class RolesController < ApplicationController
        include RansackSearchable

        before_action :set_role, only: %i[show update destroy]

        def index
          authorize Role
          result = apply_ransack_search(policy_scope(Role), default_sort: "name asc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: RoleBlueprint.render_as_hash(records), meta: pagination_meta(pagy) }
        end

        def show
          authorize @role
          render json: { status: "success", data: RoleBlueprint.render_as_hash(@role) }
        end

        def create
          authorize Role

          result = Roles::Create.call(role_params, platform_scope: Role::FISHERMAN_PLATFORM,
                                                   company_profile_id: current_user.company_profile_id,
                                                   permission_codes: params[:permission_codes])
          case result
          in Success(role)
            render json: { status: "success", data: RoleBlueprint.render_as_hash(role) }, status: :created
          in Failure(role)
            render json: { status: "fail", errors: role.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          authorize @role

          result = Roles::Update.call(@role, role_params, platform_scope: Role::FISHERMAN_PLATFORM,
                                                          company_profile_id: current_user.company_profile_id,
                                                          permission_codes: params[:permission_codes])
          case result
          in Success(role)
            render json: { status: "success", data: RoleBlueprint.render_as_hash(role) }
          in Failure(role)
            render json: { status: "fail", errors: role.errors.full_messages }, status: :unprocessable_content
          end
        end

        def destroy
          authorize @role

          if @role.destroy
            render json: { status: "success", message: "Role removed." }
          else
            render json: { status: "fail", errors: @role.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        # Unlike Admin::RolesController's raw Role.find (admin has no scoping concern — it always
        # owns every dofi_officer-platform role), this must go through policy_scope so another
        # company's role 404s via RecordNotFound rather than 403ing via Pundit and confirming the ID
        # exists at all — matching this codebase's convention for fisherman-side multi-tenant
        # resources (see Fisherman::UsersController#set_user, Fisherman::ManifestsController).
        def set_role
          @role = policy_scope(Role).find(params.expect(:id))
        end

        def role_params
          params.expect(role: %i[name description])
        end
      end
    end
  end
end
