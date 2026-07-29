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
