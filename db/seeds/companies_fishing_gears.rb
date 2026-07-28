commercial_profile = CompanyProfile.find_by!(company_name: "Sinar Jaya Fisheries Sdn Bhd")
small_scale_company_profile = CompanyProfile.find_by!(company_name: "Pantai Emas Enterprise")
full_time_profile = CompanyProfileContact.find_by!(ic_no: "00456789").company_profile
admin = User.find_by!(email: "admin@dofi.gov.bn")

sinar_bahari_first = commercial_profile.companies_vessels.find_by!(boat_number: "BSB-1001")
emas_laut = small_scale_company_profile.companies_vessels.find_by!(boat_number: "TUT-2001")
perahu_norhayati = full_time_profile.companies_vessels.find_by!(boat_number: "TUT-3001")

drift_gill_net = FishingGear.find_by!(name: "Drift Gill Net")
trawler = FishingGear.find_by!(name: "Trawler")

COMPANIES_FISHING_GEARS = [
  { company_profile: commercial_profile, companies_vessel: sinar_bahari_first, fishing_gear: trawler,
    local_name: "Pukat Tunda", quantity: 2, usage_value: 50, approve: true },
  { company_profile: small_scale_company_profile, companies_vessel: emas_laut, fishing_gear: drift_gill_net,
    local_name: "Jaring Insang Hanyut", quantity: 5, usage_value: 30, approve: true },
  { company_profile: full_time_profile, companies_vessel: perahu_norhayati, fishing_gear: drift_gill_net,
    local_name: "Jaring Insang Hanyut", quantity: 3, usage_value: 20, approve: true }
].freeze

COMPANIES_FISHING_GEARS.each do |attrs|
  attrs = attrs.dup
  approve = attrs.delete(:approve)
  company_profile = attrs.delete(:company_profile)

  gear = company_profile.companies_fishing_gears.find_or_create_by!(fishing_gear: attrs[:fishing_gear]) do |g|
    g.assign_attributes(attrs)
  end
  gear.approve!(actor: admin) if approve && gear.may_approve?
end

puts "Seeded #{CompaniesFishingGear.count} company fishing gears (#{CompaniesFishingGear.approved.count} approved)"
