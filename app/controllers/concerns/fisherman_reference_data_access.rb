module FishermanReferenceDataAccess
  extend ActiveSupport::Concern

  private

  # Fisherman reference-data endpoints are guarded by the authenticated Fisherman audience at the
  # route level. They intentionally do not require an RBAC permission because lookup data is needed
  # while completing the operational forms.
  def reference_data_permission_required? = false
end
