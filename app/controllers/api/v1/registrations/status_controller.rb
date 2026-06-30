module Api
  module V1
    module Registrations
      class StatusController < ApplicationController
        skip_before_action :authenticate_user!, only: :show

        def show
          user = User.kept.find_by!(ic_number: params.expect(:ic_number))
          render json: { status: "success", data: UserBlueprint.render_as_hash(user) }
        end
      end
    end
  end
end
