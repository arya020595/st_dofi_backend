default_password = ENV.fetch("ADMIN_DEFAULT_PASSWORD", "ChangeMe123!")
jetty_manager_role = Role.find_by!(kind: Role::JETTY_MANAGER)

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
