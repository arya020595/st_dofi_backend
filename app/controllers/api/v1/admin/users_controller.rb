module Api
  module V1
    module Admin
      class UsersController < ApplicationController
        include RansackSearchable

        before_action :set_user, only: %i[show update destroy]

        def index
          authorize User
          result = apply_ransack_search(policy_scope(User), default_sort: "created_at desc")
          pagy, records = pagy(:offset, result)
          render json: { status: "success", data: UserBlueprint.render_as_hash(records), meta: pagination_meta(pagy) }
        end

        def show
          authorize @user
          render json: { status: "success", data: UserBlueprint.render_as_hash(@user) }
        end

        def create
          authorize User

          case Users::Create.call(user_params, assignable_roles: Role.assignable_by_admin)
          in Success(user)
            data = UserBlueprint.render_as_hash(user)
            data = data.merge(temporary_password: user.password) if user_params[:password].blank?
            render json: { status: "success", data: data }, status: :created
          in Failure(user)
            render json: { status: "fail", errors: user.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          authorize @user

          case Users::Update.call(@user, user_params, assignable_roles: Role.assignable_by_admin)
          in Success(user)
            render json: { status: "success", data: UserBlueprint.render_as_hash(user) }
          in Failure(user)
            render json: { status: "fail", errors: user.errors.full_messages }, status: :unprocessable_content
          end
        end

        def destroy
          authorize @user

          if @user.discard
            render json: { status: "success", message: "User removed." }
          else
            render json: { status: "fail", errors: @user.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def set_user
          @user = policy_scope(User).find(params.expect(:id))
        end

        def user_params
          params.expect(user: %i[name email password password_confirmation employee_id role_id username
                                 status preferred_locale unit position contact_no designation])
        end
      end
    end
  end
end
