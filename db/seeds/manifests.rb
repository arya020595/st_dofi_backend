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
  "Small - Scale (Full-Time)" => "small_scale_full_time",
  "Small - Scale (Part-Time)" => "small_scale_part_time"
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
  manifest1.create_manifest_expense!(fuel_litres: 180, fuel_bnd: 320.50, ice_litres: 60, ice_bnd: 45.00,
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

# --- Manifest 4: Commercial, port_out submitted and awaiting Jetty Manager approval -----------------
manifest4 = Manifest.find_or_create_by!(manifest_number: "DOF-SEED-0004") do |m|
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
  m.port_out_datetime = 4.hours.ago
  m.zone = offshore_zone
  m.zone_area = offshore_zone.name
end

if manifest4.crew_manifests.none?
  crew_aliff = commercial_profile.companies_crews.approved.find_by!(ic_number: "00890123")
  manifest4.crew_manifests.create!(companies_crew: crew_aliff, crew_name: crew_aliff.crew_name,
                                   ic_number: crew_aliff.ic_number, passport_number: crew_aliff.passport_number,
                                   date_of_birth: crew_aliff.date_of_birth, position: crew_aliff.position,
                                   nationality: crew_aliff.nationality)
end

manifest4.submit_port_out!(actor: commercial_owner) if manifest4.may_submit_port_out?

# --- Manifest 5: Commercial, port_out amendment requested by the Jetty Manager ----------------------
manifest5 = Manifest.find_or_create_by!(manifest_number: "DOF-SEED-0005") do |m|
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
  m.port_out_datetime = 5.hours.ago
  m.zone = offshore_zone
  m.zone_area = offshore_zone.name
end

if manifest5.crew_manifests.none?
  crew_aliff = commercial_profile.companies_crews.approved.find_by!(ic_number: "00890123")
  manifest5.crew_manifests.create!(companies_crew: crew_aliff, crew_name: crew_aliff.crew_name,
                                   ic_number: crew_aliff.ic_number, passport_number: crew_aliff.passport_number,
                                   date_of_birth: crew_aliff.date_of_birth, position: crew_aliff.position,
                                   nationality: crew_aliff.nationality)
end

if manifest5.may_submit_port_out?
  manifest5.submit_port_out!(actor: commercial_owner)
  manifest5.request_amendment_port_out!(actor: admin,
                                        remarks: "Vessel boat number does not match jetty log — please confirm.")
end

# --- Manifest 6: Commercial, port_out approved (at sea), capture report awaiting verification, ------
# --- port_in submitted and awaiting Jetty Manager approval -------------------------------------------
manifest6 = Manifest.find_or_create_by!(manifest_number: "DOF-SEED-0006") do |m|
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
  m.port_out_datetime = 2.days.ago
  m.zone = offshore_zone
  m.zone_area = offshore_zone.name
end

if manifest6.crew_manifests.none?
  crew_jefri = commercial_profile.companies_crews.approved.find_by!(ic_number: "00789012")
  manifest6.crew_manifests.create!(companies_crew: crew_jefri, crew_name: crew_jefri.crew_name,
                                   ic_number: crew_jefri.ic_number, passport_number: crew_jefri.passport_number,
                                   date_of_birth: crew_jefri.date_of_birth, position: crew_jefri.position,
                                   nationality: crew_jefri.nationality)
end

if manifest6.may_submit_port_out?
  manifest6.submit_port_out!(actor: commercial_owner)
  manifest6.approve_port_out!(actor: admin)
end

if manifest6.capture_reports.none?
  report6 = manifest6.capture_reports.create!(zone: offshore_zone, zone_area: offshore_zone.name,
                                              latitude: 5.10, longitude: 115.10)
  manifest6.create_manifest_expense!(fuel_litres: 150, fuel_bnd: 270.00, ice_litres: 50, ice_bnd: 38.00,
                                     ration_bnd: 75.00)

  selar = Dictionary.find_by!(local_name: "Ikan Selar")
  report6.fish_capture_details.create!(dictionary: selar, local_name: selar.local_name,
                                       scientific_name: selar.scientific_name, fish_type: selar.group_name,
                                       amount_captured_kg: 210.0, price_per_kg: 8.0, overall_total: 210.0 * 8.0,
                                       synced_at: Time.current)

  trawler_gear6 = commercial_profile.companies_fishing_gears.approved
                                    .find_by!(fishing_gear: FishingGear.find_by!(name: "Trawler"))
  report6.fishing_gear_details.create!(companies_fishing_gear: trawler_gear6, name: trawler_gear6.fishing_gear.name,
                                       gear_type: trawler_gear6.fishing_gear.gear_type,
                                       specification: trawler_gear6.fishing_gear.gear_specification, quantity: 1)
end

if manifest6.may_submit_port_in?
  manifest6.update!(port_in: mifl_port, port_in_area: mifl_port.port_name, port_in_datetime: 1.hour.ago)
  manifest6.submit_port_in!(actor: commercial_owner)
end

# --- Manifest 7: Commercial, port_in amendment requested by the Jetty Manager -----------------------
manifest7 = Manifest.find_or_create_by!(manifest_number: "DOF-SEED-0007") do |m|
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
end

if manifest7.crew_manifests.none?
  crew_jefri = commercial_profile.companies_crews.approved.find_by!(ic_number: "00789012")
  manifest7.crew_manifests.create!(companies_crew: crew_jefri, crew_name: crew_jefri.crew_name,
                                   ic_number: crew_jefri.ic_number, passport_number: crew_jefri.passport_number,
                                   date_of_birth: crew_jefri.date_of_birth, position: crew_jefri.position,
                                   nationality: crew_jefri.nationality)
end

if manifest7.may_submit_port_out?
  manifest7.submit_port_out!(actor: commercial_owner)
  manifest7.approve_port_out!(actor: admin)
end

if manifest7.capture_reports.none?
  report7 = manifest7.capture_reports.create!(zone: offshore_zone, zone_area: offshore_zone.name,
                                              latitude: 5.11, longitude: 115.11)
  tongkol = Dictionary.find_by!(local_name: "Ikan Tongkol")
  report7.fish_capture_details.create!(dictionary: tongkol, local_name: tongkol.local_name,
                                       scientific_name: tongkol.scientific_name, fish_type: tongkol.group_name,
                                       amount_captured_kg: 180.0, price_per_kg: 9.5, overall_total: 180.0 * 9.5,
                                       synced_at: Time.current)
end

if manifest7.may_submit_port_in?
  manifest7.update!(port_in: lumut_port, port_in_area: lumut_port.port_name, port_in_datetime: 3.hours.ago)
  manifest7.submit_port_in!(actor: commercial_owner)
  manifest7.request_amendment_port_in!(actor: admin,
                                       remarks: "Port-in time is earlier than port-out — please verify.")
end

# --- Manifest 8: Small-Scale (Company), at sea, capture report sent back for amendment --------------
manifest8 = Manifest.find_or_create_by!(manifest_number: "DOF-SEED-0008") do |m|
  m.company_profile = small_scale_company_profile
  m.companies_vessel = vessel2
  m.company_name = small_scale_company_profile.company_name
  m.vessel_boat_name = vessel2.vessel_name
  m.vessel_boat_no = vessel2.boat_number
  m.fisherman_category = FISHERMAN_CATEGORY_BY_REGISTRATION_TYPE.fetch(small_scale_company_profile.registration_type)
  m.created_by = small_scale_owner
  m.port_out = lumut_port
  m.port_out_area = lumut_port.port_name
  m.port_out_datetime = 1.day.ago
  m.zone = inshore_zone
  m.zone_area = inshore_zone.name
end

if manifest8.crew_manifests.none?
  crew_hafiz = small_scale_company_profile.companies_crews.approved.find_by!(ic_number: "01012345")
  manifest8.crew_manifests.create!(companies_crew: crew_hafiz, crew_name: crew_hafiz.crew_name,
                                   ic_number: crew_hafiz.ic_number, passport_number: crew_hafiz.passport_number,
                                   date_of_birth: crew_hafiz.date_of_birth, position: crew_hafiz.position,
                                   nationality: crew_hafiz.nationality)
end

# Small-scale skips Jetty Manager approval at port-out — submit_port_out! jumps straight to :submitted.
manifest8.submit_port_out!(actor: small_scale_owner) if manifest8.may_submit_port_out?

if manifest8.capture_reports.none?
  report8 = manifest8.capture_reports.create!(zone: inshore_zone, zone_area: inshore_zone.name,
                                              latitude: 4.70, longitude: 114.90)
  bilis = Dictionary.find_by!(local_name: "Ikan Bilis")
  report8.fish_capture_details.create!(dictionary: bilis, local_name: bilis.local_name,
                                       scientific_name: bilis.scientific_name, fish_type: bilis.group_name,
                                       amount_captured_kg: 45.0, price_per_kg: 6.0, overall_total: 45.0 * 6.0,
                                       synced_at: Time.current)
end

# Left at :needs_amendment (port_in not submitted yet) — the fisherman is still expected to fix the
# catch report and resubmit before this manifest can move on to port-in.
report8 = manifest8.capture_reports.first
if report8&.may_request_amendment?
  report8.request_amendment!(actor: admin,
                             remarks: "Catch weight looks inconsistent with vessel capacity — please recheck.")
end

# --- Manifest 9: Small - Scale (Full-Time), plain draft — never submitted ---------------------------
Manifest.find_or_create_by!(manifest_number: "DOF-SEED-0009") do |m|
  m.company_profile = full_time_profile
  m.companies_vessel = vessel3
  m.company_name = full_time_profile.company_name
  m.vessel_boat_name = vessel3.vessel_name
  m.vessel_boat_no = vessel3.boat_number
  m.fisherman_category = FISHERMAN_CATEGORY_BY_REGISTRATION_TYPE.fetch(full_time_profile.registration_type)
  m.created_by = full_time_owner
  m.zone = inshore_zone
  m.zone_area = inshore_zone.name
end

# --- Manifest 10: Commercial, port_in approved but the catch report is still awaiting verification --
# --- (manifest_status: capture_report_submitted — distinct from awaiting_port_in_approval above) -----
manifest10 = Manifest.find_or_create_by!(manifest_number: "DOF-SEED-0010") do |m|
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
  m.port_out_datetime = 4.days.ago
  m.zone = offshore_zone
  m.zone_area = offshore_zone.name
end

if manifest10.crew_manifests.none?
  crew_jefri = commercial_profile.companies_crews.approved.find_by!(ic_number: "00789012")
  manifest10.crew_manifests.create!(companies_crew: crew_jefri, crew_name: crew_jefri.crew_name,
                                    ic_number: crew_jefri.ic_number, passport_number: crew_jefri.passport_number,
                                    date_of_birth: crew_jefri.date_of_birth, position: crew_jefri.position,
                                    nationality: crew_jefri.nationality)
end

if manifest10.may_submit_port_out?
  manifest10.submit_port_out!(actor: commercial_owner)
  manifest10.approve_port_out!(actor: admin)
end

if manifest10.capture_reports.none?
  report10 = manifest10.capture_reports.create!(zone: offshore_zone, zone_area: offshore_zone.name,
                                                latitude: 5.12, longitude: 115.12)
  kembung = Dictionary.find_by!(local_name: "Ikan Kembung")
  report10.fish_capture_details.create!(dictionary: kembung, local_name: kembung.local_name,
                                        scientific_name: kembung.scientific_name, fish_type: kembung.group_name,
                                        amount_captured_kg: 260.0, price_per_kg: 7.5, overall_total: 260.0 * 7.5,
                                        synced_at: Time.current)
end

if manifest10.may_submit_port_in?
  manifest10.update!(port_in: mifl_port, port_in_area: mifl_port.port_name, port_in_datetime: 2.days.ago)
  manifest10.submit_port_in!(actor: commercial_owner)
  manifest10.approve_port_in!(actor: admin)
end

puts "Seeded #{Manifest.count} manifests (#{Manifest.where(manifest_status: 'completed').count} completed), " \
     "#{CrewManifest.count} crew manifest entries, #{ManifestMinorFisherman.count} minor fishermen, " \
     "#{CaptureReport.count} capture reports, #{FishCaptureDetail.count} fish capture details, " \
     "#{FishingGearDetail.count} fishing gear details"
