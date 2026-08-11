module PlatformScopedResource
  extend ActiveSupport::Concern

  private

  # The permission-code resource name to check against, chosen by the acting user's own platform —
  # not the record's. A DoFi Officer managing roles/users checks "roles"/"dofi_officer_users"; a
  # fisherman managing their own company's roles/users checks "fisherman_roles"/"fisherman_users".
  # Including policy must define both RESOURCE (dofi_officer) and FISHERMAN_RESOURCE (fisherman).
  def resource
    user.dofi_officer_platform? ? self.class::RESOURCE : self.class::FISHERMAN_RESOURCE
  end
end
