class FishingGearDetail < ApplicationRecord
  belongs_to :capture_report
  belongs_to :companies_fishing_gear, optional: true
  has_many :fish_capture_details, dependent: :destroy

  def self.ransackable_attributes(_auth_object = nil)
    %w[id capture_report_id companies_fishing_gear_id name gear_type specification quantity created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
