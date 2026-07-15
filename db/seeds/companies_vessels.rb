commercial_profile = CompanyProfile.find_by!(company_name: "Sinar Jaya Fisheries Sdn Bhd")
small_scale_company_profile = CompanyProfile.find_by!(company_name: "Pantai Emas Enterprise")
full_time_profile = CompanyProfileContact.find_by!(ic_no: "00456789").company_profile
admin = User.find_by!(email: "admin@dofi.gov.bn")

# One vessel is left pending (approve: false) to keep a sample row in the approval queue rather than
# seeding every record pre-approved.
companies_vessels = [
  { company_profile: commercial_profile, vessel_name: "Sinar Bahari 1", boat_number: "BSB-1001", capacity: 12,
    license_reg_date: 2.years.ago.to_date, license_expiry_date: 1.year.from_now.to_date, approve: true },
  { company_profile: commercial_profile, vessel_name: "Sinar Bahari 2", boat_number: "BSB-1002", capacity: 10,
    license_reg_date: 1.year.ago.to_date, license_expiry_date: 2.years.from_now.to_date, approve: false },
  { company_profile: small_scale_company_profile, vessel_name: "Emas Laut", boat_number: "TUT-2001", capacity: 4,
    license_reg_date: 1.year.ago.to_date, license_expiry_date: 2.years.from_now.to_date, approve: true },
  { company_profile: full_time_profile, vessel_name: "Perahu Norhayati", boat_number: "TUT-3001", capacity: 1,
    license_reg_date: 6.months.ago.to_date, license_expiry_date: 18.months.from_now.to_date, approve: true }
]

companies_vessels.each do |attrs|
  attrs = attrs.dup
  approve = attrs.delete(:approve)
  company_profile = attrs.delete(:company_profile)

  vessel = company_profile.companies_vessels.find_or_create_by!(boat_number: attrs[:boat_number]) do |v|
    v.assign_attributes(attrs)
  end
  vessel.approve!(actor: admin) if approve && vessel.may_approve?
end

puts "Seeded #{CompaniesVessel.count} vessels (#{CompaniesVessel.approved.count} approved)"
