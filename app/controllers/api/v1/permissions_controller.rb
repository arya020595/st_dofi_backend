module Api
  module V1
    class PermissionsController < ApplicationController
      include RansackSearchable

      def index
        authorize Permission
        permissions = apply_ransack_search(policy_scope(Permission), default_sort: "code asc")
        render json: { status: "success", data: PermissionBlueprint.render_as_hash(permissions) }
      end
    end
  end
end
