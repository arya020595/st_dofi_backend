class Position < ApplicationRecord
  CATEGORIES = ["Fisherman", "Jetty Manager", "DoFi Officer"].freeze

  validates :name, presence: true, uniqueness: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name category created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
