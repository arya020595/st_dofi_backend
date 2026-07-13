class Dictionary < ApplicationRecord
  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_IMAGE_SIZE = 5.megabytes

  has_one_attached :image

  validates :local_name, presence: true
  validate :image_content_type_and_size, if: -> { image.attached? }

  def self.ransackable_attributes(_auth_object = nil)
    %w[id local_name scientific_name group_name family_name created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  private

  def image_content_type_and_size
    errors.add(:image, "must be a JPEG, PNG, or WebP") unless ALLOWED_IMAGE_TYPES.include?(image.content_type)
    errors.add(:image, "must be smaller than 5 MB") if image.byte_size > MAX_IMAGE_SIZE
  end
end

# == Schema Information
#
# Table name: dictionaries
# Database name: primary
#
#  id              :uuid             not null, primary key
#  family_name     :string
#  group_name      :string
#  local_name      :string           not null
#  scientific_name :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  idx_dictionaries_local_name_trgm       (local_name) USING gin
#  idx_dictionaries_scientific_name_trgm  (scientific_name) USING gin
#  index_dictionaries_on_local_name       (local_name)
#
