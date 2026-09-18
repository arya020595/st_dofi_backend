module Permissions
  class ForPlatformQuery
    def self.call(scope:, platform:)
      return scope.none if platform.blank?

      scope.where(code: Permission::Catalog.codes_for_platform(platform))
    end
  end
end
