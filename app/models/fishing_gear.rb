class FishingGear < ApplicationRecord
  validates :local_name, presence: true
  validates :name, presence: true
  validates :gear_type, presence: true
  validates :fee, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def self.ransackable_attributes(_auth_object = nil)
    %w[id local_name name gear_type unit size fee created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end

# == Schema Information
#
# Table name: fishing_gears
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  fee                :decimal(10, 2)
#  gear_specification :string
#  gear_type          :string           not null
#  local_name         :string
#  name               :string           not null
#  size               :decimal(10, 2)
#  unit               :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_fishing_gears_on_gear_type  (gear_type)
#  index_fishing_gears_on_name       (name)
#
