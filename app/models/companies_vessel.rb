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

# == Schema Information
#
# Table name: companies_vessels
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  amendment_remarks   :text
#  approval_status     :string           default("pending"), not null
#  approved_at         :datetime
#  boat_number         :string           not null
#  boat_type           :string           default("permanent"), not null
#  capacity            :integer
#  category            :string
#  charter_type        :string
#  discarded_at        :datetime
#  draft               :decimal(10, 2)
#  engine_count        :integer
#  gross_tonnage       :decimal(10, 2)
#  horse_power         :decimal(10, 2)
#  is_powered          :boolean          default(TRUE), not null
#  length              :decimal(10, 2)
#  license_expiry_date :date
#  license_reg_date    :date
#  material            :string
#  max_crew            :integer
#  registration_no     :string
#  status              :string           default("active"), not null
#  vessel_name         :string           not null
#  year_built          :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  approved_by_id      :uuid
#  company_profile_id  :uuid             not null
#  zone_id             :uuid
#
# Indexes
#
#  index_companies_vessels_on_approval_status     (approval_status)
#  index_companies_vessels_on_approved_by_id      (approved_by_id)
#  index_companies_vessels_on_boat_number         (boat_number)
#  index_companies_vessels_on_company_profile_id  (company_profile_id)
#  index_companies_vessels_on_discarded_at        (discarded_at)
#  index_companies_vessels_on_registration_no     (registration_no)
#  index_companies_vessels_on_status              (status)
#  index_companies_vessels_on_zone_id             (zone_id)
#
# Foreign Keys
#
#  fk_rails_...  (approved_by_id => users.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#  fk_rails_...  (zone_id => zones.id)
#
