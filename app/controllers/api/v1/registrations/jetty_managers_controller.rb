module Api
  module V1
    module Registrations
      class JettyManagersController < ApplicationController
        skip_before_action :authenticate_user!, only: :create

        def create
          case Users::RegisterJettyManager.call(registration_params)
          in Success(user)
            render json: { status: "success", data: UserBlueprint.render_as_hash(user) }, status: :created
          in Failure(user)
            render json: { status: "fail", errors: user.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def registration_params
          params.expect(user: %i[name ic_number unit position contact_no])
        end
      end
    end
  end
end
