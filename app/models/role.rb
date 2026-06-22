class Role < ApplicationRecord
  has_many :permission_roles, dependent: :destroy
  has_many :permissions, through: :permission_roles
  has_many :users, dependent: :nullify

  validates :reference_id, presence: true, uniqueness: true
  validates :name, presence: true, uniqueness: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id reference_id name description created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
