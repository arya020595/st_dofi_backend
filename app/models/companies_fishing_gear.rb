class CompaniesFishingGear < ApplicationRecord
  include Discard::Model
  include Approvable

  belongs_to :company_profile
  belongs_to :fishing_gear
  belongs_to :companies_vessel, optional: true

  validates :companies_vessel, presence: true, on: :create
  validate :vessel_belongs_to_company
  validate :vessel_cannot_be_cleared, on: :update

  def self.ransackable_attributes(_auth_object = nil)
    %w[id local_name quantity usage_value approval_status company_profile_id fishing_gear_id
       companies_vessel_id discarded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[fishing_gear companies_vessel]
  end

  private

  def vessel_belongs_to_company
    return if companies_vessel.blank? || companies_vessel.company_profile_id == company_profile_id

    errors.add(:companies_vessel_id, "must belong to the same company profile")
  end

  def vessel_cannot_be_cleared
    return unless will_save_change_to_companies_vessel_id? && companies_vessel_id.blank?

    errors.add(:companies_vessel_id, "cannot be blank once assigned")
  end
end

# == Schema Information
#
# Table name: companies_fishing_gears
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  amendment_remarks   :text
#  approval_status     :string           default("pending"), not null
#  approved_at         :datetime
#  discarded_at        :datetime
#  local_name          :string
#  quantity            :integer
#  usage_value         :decimal(10, 2)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  approved_by_id      :uuid
#  companies_vessel_id :uuid
#  company_profile_id  :uuid             not null
#  fishing_gear_id     :uuid             not null
#
# Indexes
#
#  index_companies_fishing_gears_on_approval_status      (approval_status)
#  index_companies_fishing_gears_on_approved_by_id       (approved_by_id)
#  index_companies_fishing_gears_on_companies_vessel_id  (companies_vessel_id)
#  index_companies_fishing_gears_on_company_profile_id   (company_profile_id)
#  index_companies_fishing_gears_on_discarded_at         (discarded_at)
#  index_companies_fishing_gears_on_fishing_gear_id      (fishing_gear_id)
#
# Foreign Keys
#
#  fk_rails_...  (approved_by_id => users.id)
#  fk_rails_...  (companies_vessel_id => companies_vessels.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#  fk_rails_...  (fishing_gear_id => fishing_gears.id)
#
