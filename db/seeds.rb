# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

SEED_FILES = %w[
  permissions
  roles
  admin_user
  nationalities
  positions
  ports
  zones
  fishing_gears
  skip_reasons
  approval_remarks
  dictionaries
  company_profiles
  companies_vessels
  companies_crews
  companies_fishing_gears
  companies_documents
  profiled_users
  brunei_id_sandbox
  manifests
].freeze

SEED_FILES.each do |file|
  load Rails.root.join("db", "seeds", "#{file}.rb")
end
