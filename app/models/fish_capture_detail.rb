class FishCaptureDetail < ApplicationRecord
  belongs_to :capture_report
  belongs_to :dictionary

  validates :amount_captured_kg, :price_per_kg, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id capture_report_id dictionary_id local_name scientific_name fish_type price_per_kg
       amount_captured_kg overall_total synced_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
