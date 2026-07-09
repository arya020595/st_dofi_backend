class Port < ApplicationRecord
  validates :port_name, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id port_name latitude longitude created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
