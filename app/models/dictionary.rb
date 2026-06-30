class Dictionary < ApplicationRecord
  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_IMAGE_SIZE = 5.megabytes

  has_one_attached :image

  before_validation :assign_reference_id, on: :create

  validates :reference_id, presence: true, uniqueness: true
  validates :local_name, presence: true
  validate :image_content_type_and_size, if: -> { image.attached? }

  def self.ransackable_attributes(_auth_object = nil)
    %w[id reference_id local_name scientific_name group_name family_name created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  private

  def image_content_type_and_size
    errors.add(:image, "must be a JPEG, PNG, or WebP") unless ALLOWED_IMAGE_TYPES.include?(image.content_type)
    errors.add(:image, "must be smaller than 5 MB") if image.byte_size > MAX_IMAGE_SIZE
  end

  def assign_reference_id
    return if reference_id.present?

    last_num = Dictionary.where("reference_id LIKE ?", "SP-%")
                         .maximum("CAST(SUBSTRING(reference_id FROM 4) AS INTEGER)") || 0
    self.reference_id = format("SP-%04d", last_num + 1)
  end
end
