admin = User.find_by!(email: "admin@dofi.gov.bn")

drift_gill_net = FishingGear.find_by!(name: "Drift Gill Net")
longline = FishingGear.find_by!(name: "Longline")
purse_seine = FishingGear.find_by!(name: "Purse Seine")
trawler = FishingGear.find_by!(name: "Trawler")

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

def fishing_gear_rows_for(definition, context)
  case definition[:code]
  when "commercial_1" then commercial_fishing_gear_rows(context)
  when "small_company_1" then small_company_fishing_gear_rows(context)
  when "full_time_1" then full_time_fishing_gear_rows(context)
  else [generic_fishing_gear_row(definition, context)]
  end
end

def commercial_fishing_gear_rows(context)
  [
    fishing_gear_row(context, boat_number: "BSB-1001", gear: :trawler, local_name: "Pukat Tunda", quantity: 2,
                              usage_value: 50),
    fishing_gear_row(context, boat_number: "BSB-1001", gear: :longline, local_name: "Rawai Laut Dalam", quantity: 4,
                              usage_value: 120),
    fishing_gear_row(context, boat_number: "BSB-1003", gear: :purse_seine, local_name: "Pukat Jerut Pelagik",
                              quantity: 1, usage_value: 2)
  ]
end

def small_company_fishing_gear_rows(context)
  [
    fishing_gear_row(context, boat_number: "TUT-2001", gear: :drift_gill_net, local_name: "Jaring Insang Hanyut",
                              quantity: 5, usage_value: 30),
    fishing_gear_row(context, boat_number: "TUT-2002", gear: :longline, local_name: "Rawai Pantai", quantity: 2,
                              usage_value: 75)
  ]
end

def full_time_fishing_gear_rows(context)
  [
    fishing_gear_row(context, boat_number: "TUT-3001", gear: :drift_gill_net, local_name: "Jaring Insang Hanyut",
                              quantity: 3, usage_value: 20),
    fishing_gear_row(context, boat_number: "TUT-3001", gear: :purse_seine, local_name: "Pukat Jerut Kecil",
                              quantity: 1, usage_value: 1)
  ]
end

def generic_fishing_gear_row(definition, context)
  gear = definition[:registration_type] == "Commercial" ? context.fetch(:trawler) : context.fetch(:drift_gill_net)
  company_profile = context.fetch(:company_profile)
  { company_profile: company_profile, companies_vessel: company_profile.companies_vessels.first,
    fishing_gear: gear, local_name: "#{gear.name} Local",
    quantity: definition[:registration_type] == "Commercial" ? 2 : 1, usage_value: 0, approve: true }
end

def fishing_gear_row(context, attributes)
  company_profile = context.fetch(:company_profile)
  { company_profile: company_profile,
    companies_vessel: company_profile.companies_vessels.find_by!(boat_number: attributes.fetch(:boat_number)),
    fishing_gear: context.fetch(attributes.fetch(:gear)), local_name: attributes.fetch(:local_name),
    quantity: attributes.fetch(:quantity), usage_value: attributes.fetch(:usage_value), approve: true }
end

fishing_gears_for = lambda do |definition|
  company_profile = profiles_by_code.fetch(definition[:code])
  fishing_gear_rows_for(definition, company_profile: company_profile, trawler: trawler, longline: longline,
                                    purse_seine: purse_seine, drift_gill_net: drift_gill_net)
end

companies_fishing_gears = []

SEED_COMPANY_PROFILES.each do |definition|
  companies_fishing_gears.concat(fishing_gears_for.call(definition))
end

companies_fishing_gears.each do |attrs|
  attrs = attrs.dup
  approve = attrs.delete(:approve)
  company_profile = attrs.delete(:company_profile)

  gear = company_profile.companies_fishing_gears.find_or_create_by!(
    companies_vessel: attrs[:companies_vessel],
    fishing_gear: attrs[:fishing_gear]
  ) do |record|
    record.assign_attributes(attrs)
  end
  gear.update!(attrs)
  apply_approval_state.call(gear, approve)
end

puts "Seeded #{CompaniesFishingGear.count} company fishing gears (#{CompaniesFishingGear.approved.count} approved)"
