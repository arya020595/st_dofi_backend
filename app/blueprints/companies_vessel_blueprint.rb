class CompaniesVesselBlueprint < Blueprinter::Base
  identifier :id

  fields :vessel_name, :boat_number, :capacity, :license_reg_date, :license_expiry_date, :status,
         :category, :registration_no, :max_crew, :gross_tonnage, :length, :horse_power, :year_built,
         :draft, :material, :is_powered, :charter_type, :boat_type, :engine_count, :approval_status,
         :amendment_remarks, :company_profile_id, :zone_id, :discarded_at, :created_at, :updated_at

  association :zone, blueprint: ZoneBlueprint

  field :image_urls do |vessel|
    vessel.images.map(&:url)
  rescue ActiveStorage::Error, Aws::Errors::ServiceError => e
    Rails.logger.error("CompaniesVessel##{vessel.id} image URL generation failed: #{e.message}")
    []
  end
end
