class CompaniesFishingGear < ApplicationRecord
  include Discard::Model
  include Approvable

  belongs_to :company_profile
  belongs_to :fishing_gear
  belongs_to :companies_vessel

  def self.ransackable_attributes(_auth_object = nil)
    %w[id local_name quantity usage_value approval_status company_profile_id fishing_gear_id
       companies_vessel_id discarded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[fishing_gear companies_vessel]
  end
end
