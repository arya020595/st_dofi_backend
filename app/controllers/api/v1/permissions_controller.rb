module Api
  module V1
    class PermissionsController < ApplicationController
      include RansackSearchable

      def index
        scope = Permissions::ForPlatformQuery.call(scope: Permission.all, platform: current_user.role&.platform_scope)
        permissions = apply_ransack_search(scope, default_sort: "code asc")
        render json: { status: "success", data: PermissionBlueprint.render_as_hash(permissions) }
      end
    end
  end
end
