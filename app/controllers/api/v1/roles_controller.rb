module Api
  module V1
    class RolesController < ApplicationController
      before_action :set_role, only: %i[show update destroy]

      def index
        authorize Role
        scope = policy_scope(Role).order(:name)
        pagy, records = pagy(:offset, scope)
        render json: { status: "success", data: RoleBlueprint.render_as_hash(records), meta: pagination_meta(pagy) }
      end

      def show
        authorize @role
        render json: { status: "success", data: RoleBlueprint.render_as_hash(@role) }
      end

      def create
        authorize Role

        case Roles::Create.call(role_params, permission_codes: params[:permission_codes])
        in Success(role)
          render json: { status: "success", data: RoleBlueprint.render_as_hash(role) }, status: :created
        in Failure(role)
          render json: { status: "fail", errors: role.errors.full_messages }, status: :unprocessable_content
        end
      end

      def update
        authorize @role

        case Roles::Update.call(@role, role_params, permission_codes: params[:permission_codes])
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
        @role = Role.find(params.expect(:id))
      end

      def role_params
        params.expect(role: %i[reference_id name description])
      end
    end
  end
end
