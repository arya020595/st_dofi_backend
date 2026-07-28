# Seeds one CompanyProfile per registration_type, mirroring CompanyProfiles::Create: a company-shaped
# profile gets Owner (+ Admin) CompanyProfileContact rows; the individual Small - Scale (Full-Time)
# profile only gets an Owner contact for the fisherman themselves (see CompanyProfile#individual? —
# company-shape fields like company_name/worker_quota stay blank for that type, not validated).
company_profiles = [
  {
    registration_type: "Commercial",
    company_name: "Sinar Jaya Fisheries Sdn Bhd",
    rocbn_no: "RC0012345",
    company_address: "Simpang 123, Kampong Lambak, Bandar Seri Begawan",
    contact_no: "+673 2345678",
    district: "Brunei-Muara",
    mukim: "Mukim Berakas",
    village: "Kampong Lambak",
    fisherman_card_no: "FC-000123",
    issue_date: 2.years.ago.to_date,
    license_expiry_date: 1.year.from_now.to_date,
    worker_quota: 25,
    owner: { full_name: "Haji Ahmad bin Salleh", gender: "Male", ic_no: "00123456", ic_colour: "Yellow" },
    admin: { full_name: "Siti Aminah binti Yusof", gender: "Female", ic_no: "00234567", ic_colour: "Yellow" }
  },
  {
    registration_type: "Small-Scale (Company)",
    company_name: "Pantai Emas Enterprise",
    rocbn_no: "RC0054321",
    company_address: "Kampong Kuala Tutong, Tutong",
    contact_no: "+673 8765432",
    district: "Tutong",
    mukim: "Mukim Pekan Tutong",
    village: "Kampong Kuala Tutong",
    fisherman_card_no: "FC-000456",
    issue_date: 1.year.ago.to_date,
    license_expiry_date: 2.years.from_now.to_date,
    worker_quota: 6,
    owner: { full_name: "Awang Zulkifli bin Hashim", gender: "Male", ic_no: "00345678", ic_colour: "Green" }
  },
  {
    registration_type: "Small - Scale (Full-Time)",
    owner: { full_name: "Dayang Norhayati binti Tuah", gender: "Female", ic_no: "00456789", ic_colour: "Green" }
  },
  {
    registration_type: "Small - Scale (Part-Time)",
    owner: { full_name: "Osman bin Haji Rosli", gender: "Male", ic_no: "00567892", ic_colour: "Green" }
  }
]

company_profiles.each do |attrs|
  owner_attrs = attrs.fetch(:owner)
  admin_attrs = attrs[:admin]

  profile = CompanyProfile.find_or_create_by!(registration_type: attrs[:registration_type],
                                              company_name: attrs[:company_name]) do |p|
    p.assign_attributes(attrs.except(:owner, :admin))
  end

  profile.contacts.find_or_create_by!(designation: "Owner") { |contact| contact.assign_attributes(owner_attrs) }
  if admin_attrs
    profile.contacts.find_or_create_by!(designation: "Admin") { |contact| contact.assign_attributes(admin_attrs) }
  end
end

puts "Seeded #{CompanyProfile.count} company profiles with #{CompanyProfileContact.count} contacts"
