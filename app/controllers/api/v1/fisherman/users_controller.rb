module Api
  module V1
    module Fisherman
      # Company-scoped mirror of Admin::UsersController — a company managing its own teammates.
      # company_profile is always server-derived from current_user, never a client param (same
      # precedent as Manifests::Create deriving company_profile from the acting fisherman), and only
      # this company's own fisherman-platform roles are assignable (see UserPolicy,
      # Role.assignable_by_fisherman).
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

          case Users::Create.call(create_params, assignable_roles: assignable_roles)
          in Success(user)
            data = UserBlueprint.render_as_hash(user)
            data = data.merge(temporary_password: user.password) if create_params[:password].blank?
            render json: { status: "success", data: data }, status: :created
          in Failure(user)
            render json: { status: "fail", errors: user.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          authorize @user

          case Users::Update.call(@user, user_params, assignable_roles: assignable_roles)
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

        def assignable_roles = Role.assignable_by_fisherman(current_user.company_profile_id)

        def create_params
          user_params.merge(company_profile: current_user.company_profile)
        end

        def user_params
          params.expect(user: %i[name email password password_confirmation role_id ic_number
                                 registration_type contact_no designation preferred_locale])
        end
      end
    end
  end
end
