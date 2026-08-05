class Position < ApplicationRecord
  CATEGORIES = ["Fisherman", "Jetty Manager", "DoFi Officer", "Crew"].freeze

  validates :name, presence: true, uniqueness: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name category created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end

# == Schema Information
#
# Table name: positions
# Database name: primary
#
#  id         :uuid             not null, primary key
#  category   :string
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_positions_on_name  (name) UNIQUE
#
