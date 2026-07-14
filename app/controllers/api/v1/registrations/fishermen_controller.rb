module Api
  module V1
    module Registrations
      class FishermenController < ApplicationController
        skip_before_action :authenticate_user!, only: :create

        def create
          case Users::RegisterFisherman.call(registration_params)
          in Success(user)
            render json: { status: "success", data: UserBlueprint.render_as_hash(user) }, status: :created
          in Failure(:contact_not_found)
            render json: { status: "fail", message: I18n.t("errors.company_contact_not_found") },
                   status: :not_found
          in Failure(user)
            render json: { status: "fail", errors: user.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def registration_params
          params.expect(user: %i[name ic_number registration_type designation])
        end
      end
    end
  end
end
