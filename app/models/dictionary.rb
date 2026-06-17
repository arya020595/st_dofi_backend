class Dictionary < ApplicationRecord
  validates :reference_id, presence: true, uniqueness: true
  validates :local_name, presence: true
end
