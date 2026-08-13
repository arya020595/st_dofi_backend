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

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/ParameterLists
def fishing_gear_rows_for(definition, company_profile, trawler, longline, purse_seine, drift_gill_net)
  case definition[:code]
  when "commercial_1"
    [
      { company_profile:, companies_vessel: company_profile.companies_vessels.find_by!(boat_number: "BSB-1001"),
        fishing_gear: trawler, local_name: "Pukat Tunda", quantity: 2, usage_value: 50, approve: true },
      { company_profile:, companies_vessel: company_profile.companies_vessels.find_by!(boat_number: "BSB-1001"),
        fishing_gear: longline, local_name: "Rawai Laut Dalam", quantity: 4, usage_value: 120, approve: true },
      { company_profile:, companies_vessel: company_profile.companies_vessels.find_by!(boat_number: "BSB-1003"),
        fishing_gear: purse_seine, local_name: "Pukat Jerut Pelagik", quantity: 1, usage_value: 2, approve: true }
    ]
  when "small_company_1"
    [
      { company_profile:, companies_vessel: company_profile.companies_vessels.find_by!(boat_number: "TUT-2001"),
        fishing_gear: drift_gill_net, local_name: "Jaring Insang Hanyut", quantity: 5, usage_value: 30, approve: true },
      { company_profile:, companies_vessel: company_profile.companies_vessels.find_by!(boat_number: "TUT-2002"),
        fishing_gear: longline, local_name: "Rawai Pantai", quantity: 2, usage_value: 75, approve: true }
    ]
  when "full_time_1"
    [
      { company_profile:, companies_vessel: company_profile.companies_vessels.find_by!(boat_number: "TUT-3001"),
        fishing_gear: drift_gill_net, local_name: "Jaring Insang Hanyut", quantity: 3, usage_value: 20, approve: true },
      { company_profile:, companies_vessel: company_profile.companies_vessels.find_by!(boat_number: "TUT-3001"),
        fishing_gear: purse_seine, local_name: "Pukat Jerut Kecil", quantity: 1, usage_value: 1, approve: true }
    ]
  else
    vessel = company_profile.companies_vessels.first
    gear = definition[:registration_type] == "Commercial" ? trawler : drift_gill_net

    [
      { company_profile:, companies_vessel: vessel, fishing_gear: gear, local_name: "#{gear.name} Local",
        quantity: definition[:registration_type] == "Commercial" ? 2 : 1, usage_value: 0, approve: true }
    ]
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/ParameterLists

fishing_gears_for = lambda do |definition|
  company_profile = profiles_by_code.fetch(definition[:code])
  fishing_gear_rows_for(definition, company_profile, trawler, longline, purse_seine, drift_gill_net)
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
