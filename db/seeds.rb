# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Reference data every environment needs.
reference_seed_files = %w[
  database_number_triggers
  permissions
  roles
  admin_user
  nationalities
  positions
  ports
  zones
  fishing_gears
  skip_reasons
  dictionaries
]

# Demo data for local, test and staging. profiled_users and brunei_id_sandbox create Fisherman and Jetty Manager
# users with a known default password (ADMIN_DEFAULT_PASSWORD, "ChangeMe123!") who can sign in with it, so none of
# this loads on production. It is the whole group because manifests looks the demo Fishermen up.
demo_seed_files = %w[
  company_profiles
  companies_vessels
  companies_crews
  companies_fishing_gears
  companies_documents
  profiled_users
  brunei_id_sandbox
  manifests
]

seed_files = reference_seed_files
if Authentication::DirectoryConfig.current.production?
  puts "DEPLOY_ENV=production: skipping the demo seeds (no accounts with a known default password)."
else
  seed_files += demo_seed_files
end

seed_files.each do |file|
  load Rails.root.join("db", "seeds", "#{file}.rb")
end
