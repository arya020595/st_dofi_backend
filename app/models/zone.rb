class Zone < ApplicationRecord
  validates :name, presence: true
  validates :start_range, presence: true
  validates :end_range, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name zone_type start_range end_range created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
