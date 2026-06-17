class Port < ApplicationRecord
  validates :reference_id, presence: true, uniqueness: true
  validates :port_name, presence: true
end
