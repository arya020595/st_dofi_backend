module Api
  module V1
    module Registrations
      class CompanyProfileLookupsController < ApplicationController
        skip_before_action :authenticate_user!, only: :create
        rescue_from ActiveSupport::MessageVerifier::InvalidSignature, with: :render_invalid_lookup_token
        rescue_from ActiveRecord::RecordNotFound, with: :render_profiling_not_found

        def create
          contact = CompanyProfileContact.kept.find_by!(ic_no: verified_ic_no)
          render json: { status: "success", data: CompanyProfileContactLookupBlueprint.render_as_hash(contact) }
        end

        private

        def verified_ic_no
          Registrations::FishermanCompanyProfileLookupToken.verify!(params.expect(:lookup_token))
        end

        def render_invalid_lookup_token
          render json: {
            status: "fail",
            message: "Lookup token is invalid or expired.",
            code: "invalid_lookup_token"
          }, status: :unauthorized
        end

        def render_profiling_not_found
          render json: {
            status: "fail",
            message: "Profiling data not found.",
            code: "profiling_not_found"
          }, status: :not_found
        end
      end
    end
  end
end
