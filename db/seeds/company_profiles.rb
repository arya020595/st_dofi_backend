Object.send(:remove_const, :SEED_COMPANY_PROFILES) if defined?(SEED_COMPANY_PROFILES)

def months_ago_date(count)
  count.months.ago.to_date
end

def months_from_now_date(count)
  count.months.from_now.to_date
end

def years_ago_date(count)
  count.years.ago.to_date
end

def years_from_now_date(count)
  count.years.from_now.to_date
end

SEED_COMPANY_PROFILES = [
  {
    code: "commercial_1",
    review_state: :approved,
    registration_type: "Commercial",
    company_name: "Sinar Jaya Fisheries Sdn Bhd",
    rocbn_no: "RC0012345",
    company_address: "Simpang 123, Kampong Lambak, Bandar Seri Begawan",
    contact_no: "+673 2345678",
    district: "Brunei-Muara",
    mukim: "Mukim Berakas",
    village: "Kampong Lambak",
    fisherman_card_no: "FC-000123",
    issue_date: years_ago_date(2),
    license_expiry_date: years_from_now_date(1),
    worker_quota: 25,
    owner: { full_name: "Haji Ahmad bin Salleh", gender: "Male", ic_no: "00123456", ic_colour: "Yellow" },
    admin: { full_name: "Siti Aminah binti Yusof", gender: "Female", ic_no: "00234567", ic_colour: "Yellow" }
  },
  {
    code: "commercial_2",
    review_state: :pending_vessel,
    registration_type: "Commercial",
    company_name: "Borneo Blue Harvest Sdn Bhd",
    rocbn_no: "RC0012346",
    company_address: "Lot 18, Jalan Muara, Bandar Seri Begawan",
    contact_no: "+673 2345679",
    district: "Brunei-Muara",
    mukim: "Mukim Kota Batu",
    village: "Kampong Serasa",
    fisherman_card_no: "FC-000124",
    issue_date: months_ago_date(20),
    license_expiry_date: months_from_now_date(14),
    worker_quota: 18,
    owner: { full_name: "Awang Hafeez bin Abdullah", gender: "Male", ic_no: "10123456", ic_colour: "Yellow" },
    admin: { full_name: "Nur Diyana binti Salleh", gender: "Female", ic_no: "10234567", ic_colour: "Yellow" }
  },
  {
    code: "commercial_3",
    review_state: :pending_crew,
    registration_type: "Commercial",
    company_name: "Seri Laut Logistics Sdn Bhd",
    rocbn_no: "RC0012347",
    company_address: "No. 55, Jalan Telisai, Tutong",
    contact_no: "+673 2345680",
    district: "Tutong",
    mukim: "Mukim Keriam",
    village: "Kampong Telisai",
    fisherman_card_no: "FC-000125",
    issue_date: months_ago_date(16),
    license_expiry_date: months_from_now_date(18),
    worker_quota: 14,
    owner: { full_name: "Mohammad Aiman bin Tahir", gender: "Male", ic_no: "10345678", ic_colour: "Yellow" },
    admin: { full_name: "Siti Hajar binti Manaf", gender: "Female", ic_no: "10456789", ic_colour: "Yellow" }
  },
  {
    code: "commercial_4",
    review_state: :pending_document,
    registration_type: "Commercial",
    company_name: "Samudera Maju Marine Sdn Bhd",
    rocbn_no: "RC0012348",
    company_address: "Jalan Sungai Liang, Belait",
    contact_no: "+673 2345681",
    district: "Belait",
    mukim: "Mukim Liang",
    village: "Kampong Sungai Liang",
    fisherman_card_no: "FC-000126",
    issue_date: months_ago_date(15),
    license_expiry_date: months_from_now_date(20),
    worker_quota: 12,
    owner: { full_name: "Awang Shahiran bin Karim", gender: "Male", ic_no: "10567890", ic_colour: "Yellow" },
    admin: { full_name: "Liyana binti Hamzah", gender: "Female", ic_no: "10678901", ic_colour: "Yellow" }
  },
  {
    code: "small_company_1",
    review_state: :approved,
    registration_type: "Small-Scale (Company)",
    company_name: "Pantai Emas Enterprise",
    rocbn_no: "RC0054321",
    company_address: "Kampong Kuala Tutong, Tutong",
    contact_no: "+673 8765432",
    district: "Tutong",
    mukim: "Mukim Pekan Tutong",
    village: "Kampong Kuala Tutong",
    fisherman_card_no: "FC-000456",
    issue_date: years_ago_date(1),
    license_expiry_date: years_from_now_date(2),
    worker_quota: 6,
    owner: { full_name: "Awang Zulkifli bin Hashim", gender: "Male", ic_no: "00345678", ic_colour: "Green" },
    admin: { full_name: "Dayang Raihanah binti Adi", gender: "Female", ic_no: "11234567", ic_colour: "Green" }
  },
  {
    code: "small_company_2",
    review_state: :pending_vessel,
    registration_type: "Small-Scale (Company)",
    company_name: "Teluk Damai Ventures",
    rocbn_no: "RC0054322",
    company_address: "Kampong Danau, Tutong",
    contact_no: "+673 8765433",
    district: "Tutong",
    mukim: "Mukim Pekan Tutong",
    village: "Kampong Danau",
    fisherman_card_no: "FC-000457",
    issue_date: months_ago_date(14),
    license_expiry_date: months_from_now_date(22),
    worker_quota: 5,
    owner: { full_name: "Pengiran Jalal bin Omar", gender: "Male", ic_no: "11345678", ic_colour: "Green" },
    admin: { full_name: "Noor Fatin binti Idris", gender: "Female", ic_no: "11456789", ic_colour: "Green" }
  },
  {
    code: "small_company_3",
    review_state: :pending_crew,
    registration_type: "Small-Scale (Company)",
    company_name: "Pesisir Indah Services",
    rocbn_no: "RC0054323",
    company_address: "Kampong Lumut, Belait",
    contact_no: "+673 8765434",
    district: "Belait",
    mukim: "Mukim Liang",
    village: "Kampong Lumut",
    fisherman_card_no: "FC-000458",
    issue_date: months_ago_date(10),
    license_expiry_date: months_from_now_date(24),
    worker_quota: 4,
    owner: { full_name: "Hj Faiz bin Ahmad", gender: "Male", ic_no: "11567890", ic_colour: "Green" },
    admin: { full_name: "Nurul Izzati binti Yusuf", gender: "Female", ic_no: "11678901", ic_colour: "Green" }
  },
  {
    code: "small_company_4",
    review_state: :pending_document,
    registration_type: "Small-Scale (Company)",
    company_name: "Bahari Timur Trading",
    rocbn_no: "RC0054324",
    company_address: "Kampong Mentiri, Brunei-Muara",
    contact_no: "+673 8765435",
    district: "Brunei-Muara",
    mukim: "Mukim Mentiri",
    village: "Kampong Mentiri",
    fisherman_card_no: "FC-000459",
    issue_date: months_ago_date(9),
    license_expiry_date: months_from_now_date(26),
    worker_quota: 5,
    owner: { full_name: "Md Saiful bin Arif", gender: "Male", ic_no: "11789012", ic_colour: "Green" },
    admin: { full_name: "Aisyah binti Basri", gender: "Female", ic_no: "11890123", ic_colour: "Green" }
  },
  {
    code: "full_time_1",
    review_state: :approved,
    registration_type: "Small - Scale (Full-Time)",
    company_name: "Norhayati Family Fisheries",
    company_address: "Kampong Penapar, Tutong",
    contact_no: "+673 8456001",
    district: "Tutong",
    mukim: "Mukim Pekan Tutong",
    village: "Kampong Penapar",
    fisherman_card_no: "FC-000460",
    issue_date: months_ago_date(8),
    license_expiry_date: months_from_now_date(20),
    worker_quota: 1,
    owner: { full_name: "Dayang Norhayati binti Tuah", gender: "Female", ic_no: "00456789", ic_colour: "Green" }
  },
  {
    code: "full_time_2",
    review_state: :pending_vessel,
    registration_type: "Small - Scale (Full-Time)",
    company_name: "Fikri Coastal Catch",
    company_address: "Kampong Telamba, Tutong",
    contact_no: "+673 8456002",
    district: "Tutong",
    mukim: "Mukim Pekan Tutong",
    village: "Kampong Telamba",
    fisherman_card_no: "FC-000461",
    issue_date: months_ago_date(7),
    license_expiry_date: months_from_now_date(21),
    worker_quota: 1,
    owner: { full_name: "Mohd Fikri bin Hamdan", gender: "Male", ic_no: "12456789", ic_colour: "Green" }
  },
  {
    code: "full_time_3",
    review_state: :pending_crew,
    registration_type: "Small - Scale (Full-Time)",
    company_name: "Sufian Shoreline Catch",
    company_address: "Kampong Lugu, Brunei-Muara",
    contact_no: "+673 8456003",
    district: "Brunei-Muara",
    mukim: "Mukim Sengkurong",
    village: "Kampong Lugu",
    fisherman_card_no: "FC-000462",
    issue_date: months_ago_date(6),
    license_expiry_date: months_from_now_date(22),
    worker_quota: 1,
    owner: { full_name: "Sufian bin Ibrahim", gender: "Male", ic_no: "12567890", ic_colour: "Green" }
  },
  {
    code: "full_time_4",
    review_state: :pending_document,
    registration_type: "Small - Scale (Full-Time)",
    company_name: "Aisyah Bay Harvest",
    company_address: "Kampong Sungai Bunga, Brunei-Muara",
    contact_no: "+673 8456004",
    district: "Brunei-Muara",
    mukim: "Mukim Kota Batu",
    village: "Kampong Sungai Bunga",
    fisherman_card_no: "FC-000463",
    issue_date: months_ago_date(5),
    license_expiry_date: months_from_now_date(23),
    worker_quota: 1,
    owner: { full_name: "Nur Aisyah binti Karim", gender: "Female", ic_no: "12678901", ic_colour: "Green" }
  },
  {
    code: "part_time_1",
    review_state: :approved,
    registration_type: "Small - Scale (Part-Time)",
    company_name: "Osman Weekend Catch",
    company_address: "Kampong Kuala Belait, Belait",
    contact_no: "+673 8457001",
    district: "Belait",
    mukim: "Mukim Kuala Belait",
    village: "Kampong Kuala Belait",
    fisherman_card_no: "FC-000464",
    issue_date: months_ago_date(8),
    license_expiry_date: months_from_now_date(18),
    worker_quota: 1,
    owner: { full_name: "Osman bin Haji Rosli", gender: "Male", ic_no: "00567892", ic_colour: "Green" }
  },
  {
    code: "part_time_2",
    review_state: :pending_vessel,
    registration_type: "Small - Scale (Part-Time)",
    company_name: "Qayyum Tidal Catch",
    company_address: "Kampong Pandan, Belait",
    contact_no: "+673 8457002",
    district: "Belait",
    mukim: "Mukim Kuala Belait",
    village: "Kampong Pandan",
    fisherman_card_no: "FC-000465",
    issue_date: months_ago_date(7),
    license_expiry_date: months_from_now_date(19),
    worker_quota: 1,
    owner: { full_name: "Abdul Qayyum bin Salleh", gender: "Male", ic_no: "13456789", ic_colour: "Green" }
  },
  {
    code: "part_time_3",
    review_state: :pending_crew,
    registration_type: "Small - Scale (Part-Time)",
    company_name: "Maria Riverside Catch",
    company_address: "Kampong Lamunin, Tutong",
    contact_no: "+673 8457003",
    district: "Tutong",
    mukim: "Mukim Lamunin",
    village: "Kampong Lamunin",
    fisherman_card_no: "FC-000466",
    issue_date: months_ago_date(6),
    license_expiry_date: months_from_now_date(20),
    worker_quota: 1,
    owner: { full_name: "Hjh Maria binti Hassan", gender: "Female", ic_no: "13567890", ic_colour: "Green" }
  },
  {
    code: "part_time_4",
    review_state: :pending_document,
    registration_type: "Small - Scale (Part-Time)",
    company_name: "Alihan Estuary Catch",
    company_address: "Kampong Kiudang, Tutong",
    contact_no: "+673 8457004",
    district: "Tutong",
    mukim: "Mukim Kiudang",
    village: "Kampong Kiudang",
    fisherman_card_no: "FC-000467",
    issue_date: months_ago_date(5),
    license_expiry_date: months_from_now_date(21),
    worker_quota: 1,
    owner: { full_name: "Alihan bin Mat Salleh", gender: "Male", ic_no: "13678901", ic_colour: "Green" }
  }
].freeze

def upsert_company_profile_contact!(profile, designation, attrs)
  contact = profile.contacts.kept.find_or_initialize_by(designation: designation)
  contact.assign_attributes(attrs)
  contact.save!
end

SEED_COMPANY_PROFILES.each do |attrs|
  owner_ic = attrs.dig(:owner, :ic_no)
  owner_contact = CompanyProfileContact.kept.find_by(ic_no: owner_ic)
  profile = owner_contact&.company_profile || CompanyProfile.find_or_initialize_by(
    registration_type: attrs[:registration_type],
    company_name: attrs[:company_name]
  )

  profile.assign_attributes(attrs.except(:code, :review_state, :owner, :admin))
  profile.dofi_registration_no ||= SecureRandom.uuid
  profile.save!

  upsert_company_profile_contact!(profile, "Owner", attrs.fetch(:owner))
  upsert_company_profile_contact!(profile, "Admin", attrs[:admin]) if attrs[:admin]
end

puts "Seeded #{CompanyProfile.count} company profiles with #{CompanyProfileContact.count} contacts"
