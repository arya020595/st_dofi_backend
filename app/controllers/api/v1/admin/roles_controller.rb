module Api
  module V1
    module Admin
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

          case Roles::Create.call(role_params, platform_scope: Role::DOFI_OFFICER_PLATFORM,
                                               permission_codes: params[:permission_codes])
          in Success(role)
            render json: { status: "success", data: RoleBlueprint.render_as_hash(role) }, status: :created
          in Failure(role)
            render json: { status: "fail", errors: role.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          authorize @role

          case Roles::Update.call(@role, role_params, platform_scope: Role::DOFI_OFFICER_PLATFORM,
                                                      permission_codes: params[:permission_codes])
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
