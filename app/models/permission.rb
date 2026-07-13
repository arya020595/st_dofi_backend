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

# == Schema Information
#
# Table name: permissions
# Database name: primary
#
#  id         :uuid             not null, primary key
#  code       :string           not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_permissions_on_code  (code) UNIQUE
#
