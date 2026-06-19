module Api
  module V1
    class PermissionsController < ApplicationController
      def index
        authorize Permission
        permissions = policy_scope(Permission).order(:code)
        render json: { status: "success", data: PermissionBlueprint.render_as_hash(permissions) }
      end
    end
  end
end
