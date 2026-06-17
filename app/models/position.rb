class Position < ApplicationRecord
  validates :name, presence: true, uniqueness: true
end
