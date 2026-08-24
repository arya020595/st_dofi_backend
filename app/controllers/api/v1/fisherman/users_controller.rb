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

          role = role_for_create
          return render_unassignable_role if user_params[:role_id].present? && role.nil?

          render_provision_result(provision_user(role))
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

        def role_for_create = assignable_roles.find_by(id: user_params[:role_id])

        def render_unassignable_role
          render json: { status: "fail", errors: ["Role is not a role available to you"] },
                 status: :unprocessable_content
        end

        def render_provision_result(result)
          case result
          in Success(user)
            render json: { status: "success", data: UserBlueprint.render_as_hash(user) }, status: :created
          in Failure(user) if user.respond_to?(:errors)
            render json: { status: "fail", errors: user.errors.full_messages }, status: :unprocessable_content
          in Failure(reason)
            render json: { status: "fail", errors: [reason.to_s.humanize] }, status: :unprocessable_content
          end
        end

        def provision_user(role)
          ::Fisherman::ProvisionUser.call(
            company_profile: current_user.company_profile,
            provisioning_source: ::Fisherman::ProvisionUser::FISHERMAN_OWNER,
            created_by: current_user,
            name: user_params[:name],
            ic_number: user_params[:ic_number],
            role: role
          )
        end

        def user_params
          params.expect(user: %i[name email password password_confirmation role_id ic_number
                                 registration_type contact_no designation preferred_locale])
        end
      end
    end
  end
end
