admin = User.find_by!(email: "admin@dofi.gov.bn")

zone_inshore_1a = Zone.find_by!(name: "Zone 1A Keatas")
zone_inshore_two = Zone.find_by!(name: "Zone 2 Keatas")

profiles_by_code = SEED_COMPANY_PROFILES.to_h do |definition|
  [definition[:code], CompanyProfileContact.find_by!(ic_no: definition.dig(:owner, :ic_no)).company_profile]
end

apply_approval_state = lambda do |record, approve|
  if approve
    record.resubmit!(actor: admin) if record.may_resubmit?
    record.approve!(actor: admin) if record.may_approve?
  elsif record.may_resubmit?
    record.resubmit!(actor: admin)
  end
end

generic_vessel = lambda do |definition, company_profile, suffix|
  zone = definition[:registration_type] == "Commercial" ? zone_inshore_two : zone_inshore_1a

  {
    company_profile: company_profile,
    vessel_name: "#{definition[:company_name]} Vessel #{suffix}",
    boat_number: "#{definition[:code].upcase.gsub('_', '-')}-#{suffix}",
    capacity: definition[:registration_type] == "Commercial" ? 12 : 3,
    license_reg_date: 10.months.ago.to_date,
    license_expiry_date: 18.months.from_now.to_date,
    status: "active",
    category: definition[:registration_type] == "Commercial" ? "mother_boat" : "support_vessel",
    zone: zone,
    registration_no: "REG-#{definition[:code].upcase}-#{suffix}",
    max_crew: definition[:registration_type] == "Commercial" ? 12 : 3,
    gross_tonnage: definition[:registration_type] == "Commercial" ? 14.5 : 3.25,
    length: definition[:registration_type] == "Commercial" ? 14.0 : 7.8,
    horse_power: definition[:registration_type] == "Commercial" ? 220 : 75,
    engine_count: 1,
    year_built: 2022,
    draft: definition[:registration_type] == "Commercial" ? 1.8 : 0.9,
    material: definition[:registration_type] == "Commercial" ? "steel" : "wood",
    is_powered: true,
    charter_type: definition[:registration_type] == "Commercial" ? "own" : "charter",
    boat_type: "permanent"
  }
end

def vessel_rows_for(definition, context)
  case definition[:code]
  when "commercial_1" then commercial_vessel_rows(context)
  when "small_company_1" then small_company_vessel_rows(context)
  when "full_time_1" then full_time_vessel_rows(context)
  else [generic_vessel_row(definition, context)]
  end
end

def commercial_vessel_rows(context)
  [sinar_bahari_one(context), sinar_bahari_two(context), sinar_bahari_three(context)]
end

def small_company_vessel_rows(context)
  [emas_laut_one(context), emas_laut_two(context)]
end

def full_time_vessel_rows(context)
  [perahu_norhayati(context)]
end

def sinar_bahari_one(context)
  vessel_row(context, vessel_name: "Sinar Bahari 1", boat_number: "BSB-1001", capacity: 12,
                      license_reg_date: 2.years.ago.to_date, license_expiry_date: 1.year.from_now.to_date,
                      category: "mother_boat", zone: :zone_inshore_two, registration_no: "REG-BSB-1001",
                      max_crew: 25)
end

def sinar_bahari_two(context)
  vessel_row(context, vessel_name: "Sinar Bahari 2", boat_number: "BSB-1002", capacity: 10,
                      license_reg_date: 1.year.ago.to_date, license_expiry_date: 2.years.from_now.to_date,
                      category: "support_vessel", zone: :zone_inshore_two, registration_no: "REG-BSB-1002",
                      max_crew: 15)
end

def sinar_bahari_three(context)
  vessel_row(context, sinar_bahari_three_attributes)
end

def sinar_bahari_three_attributes
  { vessel_name: "Sinar Bahari 3", boat_number: "BSB-1003", capacity: 16,
    license_reg_date: 18.months.ago.to_date, license_expiry_date: 18.months.from_now.to_date,
    category: "mother_boat", zone: :zone_inshore_two, registration_no: "REG-BSB-1003",
    max_crew: 22, gross_tonnage: 18.75, length: 17.5, horse_power: 280, engine_count: 2,
    year_built: 2021, draft: 2.2, material: "steel", is_powered: true, charter_type: "own",
    boat_type: "permanent" }
end

def emas_laut_one(context)
  vessel_row(context, vessel_name: "Emas Laut", boat_number: "TUT-2001", capacity: 4,
                      license_reg_date: 1.year.ago.to_date, license_expiry_date: 2.years.from_now.to_date,
                      category: "mother_boat", zone: :zone_inshore_1a, registration_no: "REG-TUT-2001", max_crew: 6)
end

def emas_laut_two(context)
  vessel_row(context, emas_laut_two_attributes)
end

def emas_laut_two_attributes
  { vessel_name: "Emas Laut 2", boat_number: "TUT-2002", capacity: 3,
    license_reg_date: 8.months.ago.to_date, license_expiry_date: 28.months.from_now.to_date,
    category: "mother_boat", zone: :zone_inshore_1a, registration_no: "REG-TUT-2002",
    max_crew: 4, length: 8.5, horse_power: 85, engine_count: 1, year_built: 2023,
    material: "carbon_fiber", is_powered: true, charter_type: "charter", boat_type: "temporary" }
end

def perahu_norhayati(context)
  vessel_row(context, vessel_name: "Perahu Norhayati", boat_number: "TUT-3001", capacity: 1,
                      license_reg_date: 6.months.ago.to_date, license_expiry_date: 18.months.from_now.to_date,
                      category: "support_vessel", zone: :zone_inshore_1a, registration_no: "REG-TUT-3001",
                      max_crew: 1)
end

def generic_vessel_row(definition, context)
  context.fetch(:generic_vessel).call(definition, context.fetch(:company_profile), "01")
         .merge(approve: definition[:review_state] != :pending_vessel)
end

def vessel_row(context, attributes)
  attributes.merge(company_profile: context.fetch(:company_profile), status: "active", approve: true,
                   zone: context.fetch(attributes.fetch(:zone)))
end

vessels_for = lambda do |definition|
  company_profile = profiles_by_code.fetch(definition[:code])
  vessel_rows_for(definition, company_profile: company_profile, generic_vessel: generic_vessel,
                              zone_inshore_1a: zone_inshore_1a, zone_inshore_two: zone_inshore_two)
end

companies_vessels = []

SEED_COMPANY_PROFILES.each do |definition|
  companies_vessels.concat(vessels_for.call(definition))
end

companies_vessels.each do |attrs|
  attrs = attrs.dup
  approve = attrs.delete(:approve)
  company_profile = attrs.delete(:company_profile)

  vessel = company_profile.companies_vessels.find_or_create_by!(boat_number: attrs[:boat_number]) do |record|
    record.assign_attributes(attrs)
  end
  vessel.update!(attrs)
  apply_approval_state.call(vessel, approve)
end

puts "Seeded #{CompaniesVessel.count} vessels (#{CompaniesVessel.approved.count} approved)"
