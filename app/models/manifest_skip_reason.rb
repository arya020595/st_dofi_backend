class ManifestSkipReason < ApplicationRecord
  include Discard::Model

  validates :name, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name discarded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
