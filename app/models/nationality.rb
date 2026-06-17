class Nationality < ApplicationRecord
  validates :name, presence: true, uniqueness: true
end
