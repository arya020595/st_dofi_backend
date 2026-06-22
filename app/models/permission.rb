class Permission < ApplicationRecord
  has_many :permission_roles, dependent: :destroy
  has_many :roles, through: :permission_roles

  validates :name, presence: true
  validates :code, presence: true, uniqueness: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id code name created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
