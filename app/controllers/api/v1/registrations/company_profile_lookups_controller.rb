module Api
  module V1
    module Registrations
      class CompanyProfileLookupsController < ApplicationController
        skip_before_action :authenticate_user!, only: :show

        def show
          company_profile = CompanyProfile.kept.find_by!(ic_no: params.expect(:ic_no))
          render json: { status: "success", data: CompanyProfileBlueprint.render_as_hash(company_profile) }
        end
      end
    end
  end
end
