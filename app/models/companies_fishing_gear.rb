class CompaniesFishingGear < ApplicationRecord
  include Discard::Model
  include Approvable

  belongs_to :company_profile
  belongs_to :fishing_gear

  def self.ransackable_attributes(_auth_object = nil)
    %w[id local_name quantity approval_status company_profile_id fishing_gear_id
       discarded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[fishing_gear]
  end
end
