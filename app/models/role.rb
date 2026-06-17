class Role < ApplicationRecord
  has_many :permission_roles, dependent: :destroy
  has_many :permissions, through: :permission_roles
  has_many :users, dependent: :nullify

  validates :reference_id, presence: true, uniqueness: true
  validates :name, presence: true, uniqueness: true
end
