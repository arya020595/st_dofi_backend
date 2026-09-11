class Zone < ApplicationRecord
  validates :name, presence: true
  validates :start_range, presence: true
  validates :end_range, presence: true
  validates :start_range, numericality: { only_integer: true }
  validates :end_range, numericality: { only_integer: true }

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name start_range end_range created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end

# == Schema Information
#
# Table name: zones
# Database name: primary
#
#  id          :uuid             not null, primary key
#  end_range   :integer
#  name        :string           not null
#  start_range :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
