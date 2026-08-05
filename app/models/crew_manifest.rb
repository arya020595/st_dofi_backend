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

# == Schema Information
#
# Table name: crew_manifests
# Database name: primary
#
#  id                :uuid             not null, primary key
#  crew_name         :string
#  date_of_birth     :date
#  ic_number         :string
#  nationality       :string
#  passport_number   :string
#  position          :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  companies_crew_id :uuid
#  manifest_id       :uuid             not null
#
# Indexes
#
#  index_crew_manifests_on_companies_crew_id  (companies_crew_id)
#  index_crew_manifests_on_manifest_id        (manifest_id)
#
# Foreign Keys
#
#  fk_rails_...  (companies_crew_id => companies_crews.id)
#  fk_rails_...  (manifest_id => manifests.id)
#
