class ManifestMinorFisherman < ApplicationRecord
  belongs_to :manifest

  validates :full_name, :date_of_birth, :gender, :relationship_with_owner, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id manifest_id full_name date_of_birth gender relationship_with_owner created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
