module Api
  module V1
    module Registrations
      class CompanyProfileLookupsController < ApplicationController
        skip_before_action :authenticate_user!, only: :show

        def show
          contact = CompanyProfileContact.kept.find_by!(ic_no: params.expect(:ic_no))
          render json: { status: "success", data: CompanyProfileContactLookupBlueprint.render_as_hash(contact) }
        end
      end
    end
  end
end
