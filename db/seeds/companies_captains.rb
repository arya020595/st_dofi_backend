commercial_profile = CompanyProfile.find_by!(company_name: "Sinar Jaya Fisheries Sdn Bhd")
small_scale_company_profile = CompanyProfile.find_by!(company_name: "Pantai Emas Enterprise")
admin = User.find_by!(email: "admin@dofi.gov.bn")

# No captain for the Small - Scale (Full-Time) profile — that fisherman captains their own boat, and
# Manifest#companies_captain is optional for exactly this reason.
COMPANIES_CAPTAINS = [
  { company_profile: commercial_profile, captain_name: "Captain Rosli bin Awang", ic_number: "00567890",
    date_of_birth: Date.new(1978, 4, 12), nationality: "Bruneian", approve: true },
  { company_profile: small_scale_company_profile, captain_name: "Captain Yusof bin Hamid", ic_number: "00678901",
    date_of_birth: Date.new(1985, 9, 3), nationality: "Bruneian", approve: true }
].freeze

COMPANIES_CAPTAINS.each do |attrs|
  attrs = attrs.dup
  approve = attrs.delete(:approve)
  company_profile = attrs.delete(:company_profile)

  captain = company_profile.companies_captains.find_or_create_by!(ic_number: attrs[:ic_number]) do |c|
    c.assign_attributes(attrs)
  end
  captain.approve!(actor: admin) if approve && captain.may_approve?
end

puts "Seeded #{CompaniesCaptain.count} captains (#{CompaniesCaptain.approved.count} approved)"
