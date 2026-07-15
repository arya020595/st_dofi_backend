class CrewManifest < ApplicationRecord
  belongs_to :manifest
  belongs_to :companies_crew, optional: true

  validates :crew_name, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id manifest_id companies_crew_id crew_name ic_number passport_number position nationality
       date_of_birth created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
