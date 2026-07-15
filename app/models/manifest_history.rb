class ManifestHistory < ApplicationRecord
  belongs_to :manifest
  belongs_to :changed_by, class_name: "User", optional: true

  validates :action, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id manifest_id action status_type from_state to_state changed_by_id created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
