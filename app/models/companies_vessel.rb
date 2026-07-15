class CompaniesVessel < ApplicationRecord
  include Discard::Model
  include Approvable

  belongs_to :company_profile

  validates :vessel_name, :boat_number, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id vessel_name boat_number capacity license_reg_date license_expiry_date approval_status
       company_profile_id discarded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
