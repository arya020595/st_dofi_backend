class CompaniesVessel < ApplicationRecord
  include Discard::Model
  include Approvable

  STATUSES = %w[active non_active].freeze
  CATEGORIES = %w[mother_boat support_vessel].freeze
  MATERIALS = %w[steel carbon_fiber wood].freeze
  CHARTER_TYPES = %w[own charter].freeze
  BOAT_TYPES = %w[permanent temporary].freeze

  IMAGE_ALLOWED_TYPES = %w[image/jpeg image/png].freeze
  IMAGE_MAX_SIZE = 2.megabytes

  belongs_to :company_profile
  belongs_to :zone, optional: true
  has_many :companies_fishing_gears, dependent: :restrict_with_error
  has_many_attached :images

  validates :vessel_name, :boat_number, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :category, inclusion: { in: CATEGORIES }, allow_nil: true
  validates :material, inclusion: { in: MATERIALS }, allow_nil: true
  validates :charter_type, inclusion: { in: CHARTER_TYPES }, allow_nil: true
  validates :boat_type, inclusion: { in: BOAT_TYPES }
  validate :images_content_type_and_size

  def self.ransackable_attributes(_auth_object = nil)
    %w[id vessel_name boat_number capacity license_reg_date license_expiry_date status category
       registration_no max_crew gross_tonnage length horse_power year_built draft material
       is_powered charter_type boat_type engine_count
       approval_status company_profile_id zone_id discarded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[zone]
  end

  private

  def images_content_type_and_size
    images.each do |image|
      errors.add(:images, "must be a JPEG or PNG") unless IMAGE_ALLOWED_TYPES.include?(image.content_type)
      errors.add(:images, "must be smaller than 2 MB") if image.byte_size > IMAGE_MAX_SIZE
    end
  end
end
