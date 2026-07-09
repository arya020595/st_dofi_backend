class Nationality < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name code created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
