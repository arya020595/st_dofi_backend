class FishingGear < ApplicationRecord
  UNITS = %w[Meter Quantity].freeze

  validates :reference_id, presence: true, uniqueness: true
  validates :local_name, presence: true
  validates :name, presence: true
  validates :gear_type, presence: true
  validates :unit, presence: true, inclusion: { in: UNITS }
  validates :fee, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def self.ransackable_attributes(_auth_object = nil)
    %w[id reference_id local_name name gear_type unit size fee created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
