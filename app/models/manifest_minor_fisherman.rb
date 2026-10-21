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

# == Schema Information
#
# Table name: manifest_minor_fishermen
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  date_of_birth           :date             not null
#  full_name               :string           not null
#  gender                  :string           not null
#  relationship_with_owner :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  manifest_id             :uuid             not null
#
# Indexes
#
#  index_manifest_minor_fishermen_on_manifest_id  (manifest_id)
#
# Foreign Keys
#
#  fk_rails_...  (manifest_id => manifests.id)
#
