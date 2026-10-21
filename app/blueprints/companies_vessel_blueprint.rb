class CompaniesVesselBlueprint < Blueprinter::Base
  identifier :id

  fields :vessel_name, :boat_number, :capacity, :license_reg_date, :license_expiry_date, :status,
         :category, :registration_no, :max_crew, :gross_tonnage, :length, :horse_power, :year_built,
         :draft, :material, :is_powered, :charter_type, :boat_type, :engine_count, :approval_status,
         :amendment_remarks, :company_profile_id, :zone_id, :discarded_at, :created_at, :updated_at

  association :zone, blueprint: ZoneBlueprint

  # Vessel images live in the private bucket, so they are never embedded as storage URLs (the blob's own
  # service URL is the internal minio:9000 address, unreachable from a browser). Each slot (front/back/left/
  # right) is nil or { url:, filename: } where url is the authorized redirect path, same as
  # CompaniesDocumentBlueprint#document_url — the client requests it with its Authorization header.
  field :images do |vessel|
    CompaniesVessel::IMAGE_VIEWS.index_with do |view|
      image = vessel.image_attachment(view)
      next unless image.attached?

      { url: Rails.application.routes.url_helpers.api_v1_attachment_path(image.blob.signed_id),
        filename: image.filename.to_s }
    end
  end
end
