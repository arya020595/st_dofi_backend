class CompaniesVesselBlueprint < Blueprinter::Base
  identifier :id

  fields :vessel_name, :boat_number, :capacity, :license_reg_date, :license_expiry_date, :status,
         :category, :registration_no, :max_crew, :gross_tonnage, :length, :horse_power, :year_built,
         :draft, :material, :is_powered, :charter_type, :boat_type, :engine_count, :approval_status,
         :amendment_remarks, :company_profile_id, :zone_id, :discarded_at, :created_at, :updated_at

  association :zone, blueprint: ZoneBlueprint

  # Vessel images live in the private bucket, so they are never embedded as storage URLs (the blob's own
  # service URL is the internal minio:9000 address, unreachable from a browser). Each entry is the
  # authorized redirect path, same as CompaniesDocumentBlueprint#document_url — the client requests it
  # with its Authorization header.
  field :image_urls do |vessel|
    vessel.images.map { |image| Rails.application.routes.url_helpers.api_v1_attachment_path(image.blob.signed_id) }
  end
end
