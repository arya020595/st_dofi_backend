class ManifestSupportVessel < ApplicationRecord
  belongs_to :manifest
  belongs_to :companies_vessel

  validates :companies_vessel_id, uniqueness: { scope: :manifest_id }
  validates :vessel_name, :boat_number, presence: true
  validate :support_vessel_is_eligible

  private

  def support_vessel_is_eligible
    return if manifest.blank? || companies_vessel.blank?

    validate_distinct_vessel
    validate_same_company
    validate_approved_vessel
    validate_support_category
  end

  def validate_distinct_vessel
    return unless companies_vessel_id == manifest.companies_vessel_id

    errors.add(:companies_vessel, "must differ from the primary vessel")
  end

  def validate_same_company
    return if companies_vessel.company_profile_id == manifest.company_profile_id

    errors.add(:companies_vessel, "must belong to the same company")
  end

  def validate_approved_vessel
    errors.add(:companies_vessel, "must be approved") unless companies_vessel.approved?
  end

  def validate_support_category
    errors.add(:companies_vessel, "must be a support vessel") unless companies_vessel.category == "support_vessel"
  end
end

# == Schema Information
#
# Table name: manifest_support_vessels
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  boat_number         :string           not null
#  registration_no     :string
#  vessel_name         :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  companies_vessel_id :uuid             not null
#  manifest_id         :uuid             not null
#
# Indexes
#
#  index_manifest_support_vessels_on_companies_vessel_id  (companies_vessel_id)
#  index_manifest_support_vessels_on_manifest_id          (manifest_id)
#  index_msv_on_manifest_and_vessel                       (manifest_id,companies_vessel_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (companies_vessel_id => companies_vessels.id)
#  fk_rails_...  (manifest_id => manifests.id)
#
