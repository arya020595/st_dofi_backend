# Drives each manifest through the real AASM events (Manifest#submit_port_out!/approve_port_out!/...,
# CaptureReport#verify!) rather than writing status columns directly, so every row seeded here is
# guaranteed reachable under the guards in app/models/manifest.rb / app/models/capture_report.rb —
# and each transition still writes its ManifestHistory row via HasManifestHistory, so that table gets
# realistic data too without a dedicated seed file. manifest_number is a fixed "DOF-SEED-…" value
# rather than SequenceGenerator (see app/services/manifests/create.rb) — seeds need a stable,
# idempotent number, not the date-scoped one real submissions get.
admin = User.find_by!(email: "admin@dofi.gov.bn")

commercial_profile = CompanyProfile.find_by!(company_name: "Sinar Jaya Fisheries Sdn Bhd")
small_scale_company_profile = CompanyProfile.find_by!(company_name: "Pantai Emas Enterprise")
full_time_profile = CompanyProfileContact.find_by!(ic_no: "00456789").company_profile

commercial_owner = User.find_by!(ic_number: "00123456")
small_scale_owner = User.find_by!(ic_number: "00345678")
full_time_owner = User.find_by!(ic_number: "00456789")

serasa_port = Port.find_by!(port_name: "Serasa Port")
mifl_port = Port.find_by!(port_name: "Muara International Fish Landing (MIFL)")
lumut_port = Port.find_by!(port_name: "Lumut Port")

offshore_zone = Zone.find_by!(name: "Zone 3")
inshore_zone = Zone.find_by!(name: "Zone 1A Keatas")

no_fish_caught = ManifestSkipReason.find_by!(name: "No Fish Caught")

# Mirrors Manifests::Create::FISHERMAN_CATEGORY_BY_REGISTRATION_TYPE — derived server-side there,
# reproduced here since these rows are built directly rather than through the service.
FISHERMAN_CATEGORY_BY_REGISTRATION_TYPE = {
  "Commercial" => "commercial",
  "Small-Scale (Company)" => "small_scale_company",
  "Small - Scale (Full-Time)" => "small_scale_full_time"
}.freeze

# --- Manifest 1: Commercial, full lifecycle through to completed -----------------------------------
vessel1 = commercial_profile.companies_vessels.approved.find_by!(boat_number: "BSB-1001")
captain1 = commercial_profile.companies_captains.approved.find_by!(ic_number: "00567890")

manifest1 = Manifest.find_or_create_by!(manifest_number: "DOF-SEED-0001") do |m|
  m.company_profile = commercial_profile
  m.companies_vessel = vessel1
  m.companies_captain = captain1
  m.company_name = commercial_profile.company_name
  m.vessel_boat_name = vessel1.vessel_name
  m.vessel_boat_no = vessel1.boat_number
  m.captain_name = captain1.captain_name
  m.captain_ic_number = captain1.ic_number
  m.fisherman_category = FISHERMAN_CATEGORY_BY_REGISTRATION_TYPE.fetch(commercial_profile.registration_type)
  m.created_by = commercial_owner
  m.port_out = serasa_port
  m.port_out_area = serasa_port.port_name
  m.port_out_datetime = 3.days.ago
  m.zone = offshore_zone
  m.zone_area = offshore_zone.name
  m.latitude = 5.02
  m.longitude = 115.05
end

if manifest1.crew_manifests.none?
  crew1 = commercial_profile.companies_crews.approved.find_by!(ic_number: "00789012")
  manifest1.crew_manifests.create!(companies_crew: crew1, crew_name: crew1.crew_name, ic_number: crew1.ic_number,
                                   passport_number: crew1.passport_number, date_of_birth: crew1.date_of_birth,
                                   position: crew1.position, nationality: crew1.nationality)
  # Ad-hoc crew entry not tied to any CompaniesCrew roster row — CrewManifest#companies_crew is
  # optional for exactly this case (see Manifests::SetCrew).
  manifest1.crew_manifests.create!(crew_name: "Amir bin Zainal", ic_number: "01123456", position: "Deckhand",
                                   nationality: "Bruneian", date_of_birth: Date.new(1997, 8, 19))
end

if manifest1.may_submit_port_out?
  manifest1.submit_port_out!(actor: commercial_owner)
  manifest1.approve_port_out!(actor: admin)
end

if manifest1.capture_reports.none?
  report1 = manifest1.capture_reports.create!(zone: offshore_zone, zone_area: offshore_zone.name,
                                              latitude: 5.03, longitude: 115.06)
  report1.create_capture_report_expense!(fuel_litres: 180, fuel_bnd: 320.50, ice_litres: 60, ice_bnd: 45.00,
                                         ration_bnd: 90.00)

  tenggiri = Dictionary.find_by!(local_name: "Ikan Tenggiri")
  report1.fish_capture_details.create!(dictionary: tenggiri, local_name: tenggiri.local_name,
                                       scientific_name: tenggiri.scientific_name, fish_type: tenggiri.group_name,
                                       amount_captured_kg: 320.5, price_per_kg: 12.0, overall_total: 320.5 * 12.0,
                                       synced_at: Time.current)

  trawler_gear = commercial_profile.companies_fishing_gears.approved
                                   .find_by!(fishing_gear: FishingGear.find_by!(name: "Trawler"))
  report1.fishing_gear_details.create!(companies_fishing_gear: trawler_gear, name: trawler_gear.fishing_gear.name,
                                       gear_type: trawler_gear.fishing_gear.gear_type,
                                       specification: trawler_gear.fishing_gear.gear_specification, quantity: 2)
end

if manifest1.may_submit_port_in?
  manifest1.update!(port_in: mifl_port, port_in_area: mifl_port.port_name, port_in_datetime: 1.day.ago)
  manifest1.submit_port_in!(actor: commercial_owner)
  manifest1.approve_port_in!(actor: admin)
end

report1 = manifest1.capture_reports.first
report1.verify!(actor: admin) if report1&.may_verify?

# --- Manifest 2: Small-Scale (Company), mid-lifecycle at sea, no captain, capture report pending ---
vessel2 = small_scale_company_profile.companies_vessels.approved.find_by!(boat_number: "TUT-2001")

manifest2 = Manifest.find_or_create_by!(manifest_number: "DOF-SEED-0002") do |m|
  m.company_profile = small_scale_company_profile
  m.companies_vessel = vessel2
  m.company_name = small_scale_company_profile.company_name
  m.vessel_boat_name = vessel2.vessel_name
  m.vessel_boat_no = vessel2.boat_number
  m.fisherman_category = FISHERMAN_CATEGORY_BY_REGISTRATION_TYPE.fetch(small_scale_company_profile.registration_type)
  m.created_by = small_scale_owner
  m.port_out = lumut_port
  m.port_out_area = lumut_port.port_name
  m.port_out_datetime = 6.hours.ago
  m.zone = inshore_zone
  m.zone_area = inshore_zone.name
end

if manifest2.crew_manifests.none?
  crew2 = small_scale_company_profile.companies_crews.approved.find_by!(ic_number: "01012345")
  manifest2.crew_manifests.create!(companies_crew: crew2, crew_name: crew2.crew_name, ic_number: crew2.ic_number,
                                   passport_number: crew2.passport_number, date_of_birth: crew2.date_of_birth,
                                   position: crew2.position, nationality: crew2.nationality)
end

# Small-scale skips Jetty Manager approval at port-out — submit_port_out! jumps straight to :submitted.
manifest2.submit_port_out!(actor: small_scale_owner) if manifest2.may_submit_port_out?

# --- Manifest 3: Small - Scale (Full-Time), minor fisherman aboard, capture report skipped ---------
vessel3 = full_time_profile.companies_vessels.approved.find_by!(boat_number: "TUT-3001")

manifest3 = Manifest.find_or_create_by!(manifest_number: "DOF-SEED-0003") do |m|
  m.company_profile = full_time_profile
  m.companies_vessel = vessel3
  m.company_name = full_time_profile.company_name
  m.vessel_boat_name = vessel3.vessel_name
  m.vessel_boat_no = vessel3.boat_number
  m.fisherman_category = FISHERMAN_CATEGORY_BY_REGISTRATION_TYPE.fetch(full_time_profile.registration_type)
  m.created_by = full_time_owner
  m.has_minor_fishermen = true
  m.port_out = lumut_port
  m.port_out_area = lumut_port.port_name
  m.port_out_datetime = 2.days.ago
  m.zone = inshore_zone
  m.zone_area = inshore_zone.name
end

if manifest3.manifest_minor_fishermen.none?
  manifest3.manifest_minor_fishermen.create!(full_name: "Amir Danish bin Zulkifli",
                                             date_of_birth: Date.new(2011, 5, 9), gender: "Male",
                                             relationship_with_owner: "Son")
end

manifest3.submit_port_out!(actor: full_time_owner) if manifest3.may_submit_port_out?

if manifest3.port_in_draft? && !manifest3.capture_report_skipped?
  manifest3.update!(capture_report_skipped: true, skip_reason: no_fish_caught,
                    skip_reason_remarks: "No fish caught during this trip due to rough sea conditions.",
                    port_in: lumut_port, port_in_area: lumut_port.port_name, port_in_datetime: 1.hour.ago)
end
# Skipped reports have no CaptureReport to verify — submit_port_in! completes the manifest immediately
# via Manifest#auto_complete_if_skipped!.
manifest3.submit_port_in!(actor: full_time_owner) if manifest3.may_submit_port_in?

puts "Seeded #{Manifest.count} manifests (#{Manifest.where(manifest_status: 'completed').count} completed), " \
     "#{CrewManifest.count} crew manifest entries, #{ManifestMinorFisherman.count} minor fishermen, " \
     "#{CaptureReport.count} capture reports, #{FishCaptureDetail.count} fish capture details, " \
     "#{FishingGearDetail.count} fishing gear details"
