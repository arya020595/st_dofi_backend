class FishingGear < ApplicationRecord
  validates :reference_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :gear_type, presence: true
end
