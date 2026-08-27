require "stringio"

default_password = ENV.fetch("ADMIN_DEFAULT_PASSWORD", "ChangeMe123!")
jetty_manager_role = Role.find_by!(kind: Role::JETTY_MANAGER)
admin = User.find_by!(email: "admin@dofi.gov.bn")

BRUNEI_ID_SANDBOX_FISHERMEN = [
  {
    code: "brunei_id_sandbox_commercial",
    registration_type: "Commercial",
    ic_number: "00-100035",
    profile_name: "Brunei Id Sandbox Commercial Fisheries Sdn Bhd",
    rocbn_no: "BID-SBX-COM-001",
    company_address: "Brunei Id Sandbox Jetty Road, Muara",
    contact_no: "+673 2000035",
    district: "Brunei-Muara",
    mukim: "Mukim Serasa",
    village: "Kampong Serasa",
    fisherman_card_no: "BID-FC-COM-001",
    issue_date: Date.new(2026, 1, 8),
    license_expiry_date: Date.new(2036, 1, 8),
    worker_quota: 12,
    owner_name: "Brunei Id Sandbox Commercial Fisherman",
    gender: "Male",
    ic_colour: "Yellow",
    dofi_registration_no: "BRUNEI-ID-SANDBOX-COMMERCIAL"
  },
  {
    code: "brunei_id_sandbox_full_time",
    registration_type: "Small - Scale (Full-Time)",
    ic_number: "51-100035",
    profile_name: "Brunei Id Sandbox Full-Time Fisherman",
    company_address: "Brunei Id Sandbox Coastal Village, Tutong",
    contact_no: "+673 5100035",
    district: "Tutong",
    mukim: "Mukim Pekan Tutong",
    village: "Kampong Penapar",
    fisherman_card_no: "BID-FC-FT-001",
    issue_date: Date.new(2026, 4, 2),
    license_expiry_date: Date.new(2036, 4, 2),
    worker_quota: 1,
    owner_name: "Brunei Id Sandbox Full-Time Fisherman",
    gender: "Male",
    ic_colour: "Green",
    dofi_registration_no: "BRUNEI-ID-SANDBOX-FULL-TIME"
  }
].freeze

BRUNEI_ID_SANDBOX_JETTY_MANAGER = {
  ic_number: "31-100035",
  name: "Brunei Id Sandbox Jetty Manager",
  unit: "Brunei Id Sandbox Port",
  position: "Jetty Manager",
  contact_no: "+673 3100035"
}.freeze

SANDBOX_PROFILE_ATTRIBUTE_MAP = {
  registration_type: :registration_type,
  company_name: :profile_name,
  rocbn_no: :rocbn_no,
  company_address: :company_address,
  contact_no: :contact_no,
  district: :district,
  mukim: :mukim,
  village: :village,
  fisherman_card_no: :fisherman_card_no,
  issue_date: :issue_date,
  license_expiry_date: :license_expiry_date,
  worker_quota: :worker_quota
}.freeze

def sandbox_profile_attributes(attributes)
  SANDBOX_PROFILE_ATTRIBUTE_MAP.transform_values { |source_key| attributes[source_key] }.merge(
    approval_status: "approved",
    approved_at: Time.current,
    date_approval: Date.current
  )
end

def find_or_upsert_sandbox_profile!(attributes)
  profile = CompanyProfile.find_or_initialize_by(dofi_registration_no: attributes[:dofi_registration_no])
  profile.assign_attributes(sandbox_profile_attributes(attributes))
  profile.save!
  profile
end

def find_or_upsert_sandbox_contact!(company_profile, attributes)
  contact = CompanyProfileContact.find_or_initialize_by(company_profile:, ic_no: attributes[:ic_number])
  contact.assign_attributes(
    full_name: attributes[:owner_name],
    gender: attributes[:gender],
    ic_colour: attributes[:ic_colour],
    designation: "Owner"
  )
  contact.save!
  contact
end

def approve_sandbox_record!(record, actor)
  record.resubmit!(actor: actor) if record.may_resubmit?
  record.approve!(actor: actor) if record.may_approve?
end

def sandbox_pdf_body(company_profile)
  <<~PDF
    %PDF-1.4
    1 0 obj
    << /Type /Catalog /Pages 2 0 R >>
    endobj
    2 0 obj
    << /Type /Pages /Kids [3 0 R] /Count 1 >>
    endobj
    3 0 obj
    << /Type /Page /Parent 2 0 R /MediaBox [0 0 300 144] /Contents 4 0 R >>
    endobj
    4 0 obj
    << /Length 92 >>
    stream
    BT /F1 12 Tf 20 100 Td (Brunei Id Sandbox document for #{company_profile.company_name}) Tj ET
    endstream
    endobj
    trailer
    << /Root 1 0 R >>
    %%EOF
  PDF
end

def sandbox_profile_context(attributes)
  commercial = attributes[:registration_type] == "Commercial"
  {
    commercial: commercial,
    zone: Zone.find_by!(name: commercial ? "Zone 2 Keatas" : "Zone 1A Keatas"),
    captain_position: Position.find_by!(name: "Boat Captain"),
    crew_position: Position.find_by!(name: commercial ? "Full-Time Fisherman" : "Part-Time Fisherman"),
    fishing_gear: FishingGear.find_by!(name: commercial ? "Trawler" : "Drift Gill Net")
  }
end

def sandbox_vessel_lookup_key(attributes)
  {
    boat_number: "#{attributes[:code].upcase.gsub('_', '-')}-VESSEL-01"
  }
end

def sandbox_vessel_dimensions(context)
  {
    capacity: context[:commercial] ? 10 : 2,
    max_crew: context[:commercial] ? 10 : 2,
    gross_tonnage: context[:commercial] ? 15.5 : 3.0,
    length: context[:commercial] ? 13.5 : 7.2,
    horse_power: context[:commercial] ? 250 : 70,
    draft: context[:commercial] ? 1.7 : 0.8
  }
end

def sandbox_vessel_classification(context)
  {
    category: context[:commercial] ? "mother_boat" : "support_vessel",
    material: context[:commercial] ? "steel" : "wood",
    zone: context[:zone],
    status: "active",
    is_powered: true,
    charter_type: "own",
    boat_type: "permanent"
  }
end

def sandbox_vessel_dates(attributes)
  {
    license_reg_date: attributes[:issue_date],
    license_expiry_date: attributes[:license_expiry_date],
    year_built: 2024,
    engine_count: 1
  }
end

def sandbox_vessel_attributes(attributes, context)
  {
    vessel_name: "#{attributes[:profile_name]} Vessel",
    registration_no: "REG-#{attributes[:code].upcase}"
  }.merge(
    sandbox_vessel_dimensions(context),
    sandbox_vessel_classification(context),
    sandbox_vessel_dates(attributes)
  )
end

def persist_and_approve!(record, actor)
  record.save!
  approve_sandbox_record!(record, actor)
  record
end

def upsert_sandbox_vessel!(company_profile, attributes, context, actor)
  vessel = company_profile.companies_vessels.find_or_initialize_by(sandbox_vessel_lookup_key(attributes))
  vessel.assign_attributes(sandbox_vessel_attributes(attributes, context))
  persist_and_approve!(vessel, actor)
end

def sandbox_captain_lookup_key(context)
  {
    ic_number: context[:commercial] ? "01-100035" : "51-100035"
  }
end

def sandbox_captain_identity(attributes, context)
  {
    crew_name: "#{attributes[:owner_name]} Captain",
    date_of_birth: context[:commercial] ? Date.new(1991, 7, 11) : Date.new(1990, 12, 11),
    nationality: context[:commercial] ? "Bruneian" : "Malaysian",
    gender: attributes[:gender],
    position: context[:captain_position]
  }
end

def sandbox_captain_license(attributes)
  {
    foreign_worker_license_no: "FWL-SBX-#{attributes[:code].upcase}-CAPTAIN",
    foreign_worker_license_start_date: Date.new(2026, 1, 1),
    foreign_worker_license_end_date: Date.new(2027, 1, 1),
    status: "active"
  }
end

def sandbox_captain_attributes(attributes, context)
  sandbox_captain_identity(attributes, context).merge(
    sandbox_captain_license(attributes)
  )
end

def upsert_sandbox_captain!(company_profile, attributes, context, actor)
  captain = company_profile.companies_crews.find_or_initialize_by(sandbox_captain_lookup_key(context))
  captain.assign_attributes(sandbox_captain_attributes(attributes, context))
  persist_and_approve!(captain, actor)
end

def sandbox_crew_lookup_key(context)
  {
    ic_number: context[:commercial] ? "01-100036" : "51-100036"
  }
end

def sandbox_crew_identity(attributes, context)
  {
    crew_name: "#{attributes[:owner_name]} Crew",
    date_of_birth: context[:commercial] ? Date.new(1993, 5, 17) : Date.new(1992, 9, 20),
    nationality: context[:commercial] ? "Bruneian" : "Malaysian",
    gender: attributes[:gender],
    position: context[:crew_position]
  }
end

def sandbox_crew_license(attributes)
  {
    foreign_worker_license_no: "FWL-SBX-#{attributes[:code].upcase}-CREW",
    foreign_worker_license_start_date: Date.new(2026, 1, 1),
    foreign_worker_license_end_date: Date.new(2027, 1, 1),
    status: "active"
  }
end

def sandbox_crew_attributes(attributes, context)
  sandbox_crew_identity(attributes, context).merge(
    sandbox_crew_license(attributes)
  )
end

def upsert_sandbox_crew!(company_profile, attributes, context, actor)
  crew = company_profile.companies_crews.find_or_initialize_by(sandbox_crew_lookup_key(context))
  crew.assign_attributes(sandbox_crew_attributes(attributes, context))
  persist_and_approve!(crew, actor)
end

def sandbox_fishing_gear_attributes(context)
  {
    local_name: context[:commercial] ? "Sandbox Pukat Tunda" : "Sandbox Jaring Insang",
    quantity: context[:commercial] ? 2 : 1,
    usage_value: 0
  }
end

def upsert_sandbox_fishing_gear!(company_profile, vessel, context, actor)
  companies_fishing_gear = company_profile.companies_fishing_gears.find_or_initialize_by(
    companies_vessel: vessel,
    fishing_gear: context[:fishing_gear]
  )
  companies_fishing_gear.assign_attributes(sandbox_fishing_gear_attributes(context))
  persist_and_approve!(companies_fishing_gear, actor)
end

def sandbox_document_type(context)
  context[:commercial] ? "company_registration" : "white_card"
end

def attach_sandbox_document_file!(document, company_profile, attributes)
  return if document.file.attached?

  document.file.attach(
    io: StringIO.new(sandbox_pdf_body(company_profile)),
    filename: "#{attributes[:code]}-sandbox.pdf",
    content_type: "application/pdf"
  )
end

def upsert_sandbox_document!(company_profile, attributes, context, actor)
  document = company_profile.companies_documents.find_or_initialize_by(
    document_type: sandbox_document_type(context)
  )
  attach_sandbox_document_file!(document, company_profile, attributes)
  persist_and_approve!(document, actor)
end

def enrich_sandbox_profile!(company_profile, attributes, actor)
  context = sandbox_profile_context(attributes)
  vessel = upsert_sandbox_vessel!(company_profile, attributes, context, actor)
  upsert_sandbox_captain!(company_profile, attributes, context, actor)
  upsert_sandbox_crew!(company_profile, attributes, context, actor)
  upsert_sandbox_fishing_gear!(company_profile, vessel, context, actor)
  upsert_sandbox_document!(company_profile, attributes, context, actor)

  CompanyProfiles::SyncApprovalStatus.refresh_after_review!(company_profile, actor: actor)
end

BRUNEI_ID_SANDBOX_FISHERMEN.each do |attributes|
  company_profile = find_or_upsert_sandbox_profile!(attributes)
  contact = find_or_upsert_sandbox_contact!(company_profile, attributes)
  owner_role = Roles::EnsureFishermanOwnerRole.call(company_profile)
  owner_role.permissions = Permission.assignable_to(Role::FISHERMAN_PLATFORM)

  user = User.find_or_initialize_by(ic_number: attributes[:ic_number])
  user.assign_attributes(
    name: attributes[:owner_name],
    role: owner_role,
    registration_type: attributes[:registration_type],
    company_profile: company_profile,
    company_profile_contact: contact,
    designation: contact.designation,
    status: "active",
    preferred_locale: "en",
    brunei_id_verified_at: Time.current,
    password: default_password,
    password_confirmation: default_password
  )
  user.save!

  enrich_sandbox_profile!(company_profile, attributes, admin)
end

jetty_manager = User.find_or_initialize_by(ic_number: BRUNEI_ID_SANDBOX_JETTY_MANAGER[:ic_number])
jetty_manager.assign_attributes(
  name: BRUNEI_ID_SANDBOX_JETTY_MANAGER[:name],
  role: jetty_manager_role,
  unit: BRUNEI_ID_SANDBOX_JETTY_MANAGER[:unit],
  position: BRUNEI_ID_SANDBOX_JETTY_MANAGER[:position],
  contact_no: BRUNEI_ID_SANDBOX_JETTY_MANAGER[:contact_no],
  status: "active",
  preferred_locale: "en",
  brunei_id_verified_at: Time.current,
  password: default_password,
  password_confirmation: default_password
)
jetty_manager.save!

puts "Seeded #{BRUNEI_ID_SANDBOX_FISHERMEN.size} Brunei Id Sandbox fisherman users and 1 jetty manager user"
