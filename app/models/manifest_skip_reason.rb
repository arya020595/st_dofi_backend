class ManifestSkipReason < ApplicationRecord
  validates :reference_id, presence: true, uniqueness: true
  validates :name, presence: true
end
