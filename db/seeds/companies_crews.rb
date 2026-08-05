commercial_profile = CompanyProfile.find_by!(company_name: "Sinar Jaya Fisheries Sdn Bhd")
small_scale_company_profile = CompanyProfile.find_by!(company_name: "Pantai Emas Enterprise")
admin = User.find_by!(email: "admin@dofi.gov.bn")

boat_captain = Position.find_by!(name: "Boat Captain")
full_time_fisherman = Position.find_by!(name: "Full-Time Fisherman")
part_time_fisherman = Position.find_by!(name: "Part-Time Fisherman")
ice_storage_assistant = Position.find_by!(name: "Ice & Storage Assistant")
logistic_assistant = Position.find_by!(name: "Logistic Assistant")

# One crew member is left pending (approve: false) to keep a sample row in the approval queue.
# The two "Captain"-position rows (Rosli, Yusof) replace what used to be the separate
# CompaniesCaptain model — see docs/registration/business-flow.md for why captain is just a crew
# position now, not its own resource. No captain for the Small-Scale (Full-Time) profile — that
# fisherman captains their own boat, and Manifest#captain_crew is optional for exactly this reason.
COMPANIES_CREWS = [
  { company_profile: commercial_profile, crew_name: "Captain Rosli bin Awang", ic_number: "00567890",
    position: boat_captain, nationality: "Bruneian", date_of_birth: Date.new(1978, 4, 12), gender: "Male",
    foreign_worker_license_no: "FWL000000", foreign_worker_license_start_date: Date.new(2026, 1, 1),
    foreign_worker_license_end_date: Date.new(2027, 1, 1), approve: true },
  { company_profile: commercial_profile, crew_name: "Jefri bin Osman", ic_number: "00789012",
    position: full_time_fisherman, nationality: "Bruneian", date_of_birth: Date.new(1990, 1, 15),
    gender: "Male", foreign_worker_license_no: "FWL000001", foreign_worker_license_start_date: Date.new(2026, 1, 1),
    foreign_worker_license_end_date: Date.new(2027, 1, 1), approve: true },
  { company_profile: commercial_profile, crew_name: "Muhammad Aliff bin Rahman", ic_number: "00890123",
    position: ice_storage_assistant, nationality: "Bruneian", date_of_birth: Date.new(1993, 6, 22),
    gender: "Male", foreign_worker_license_no: "FWL000002", foreign_worker_license_start_date: Date.new(2026, 1, 1),
    foreign_worker_license_end_date: Date.new(2027, 1, 1), approve: true },
  { company_profile: commercial_profile, crew_name: "Rizal bin Kassim", ic_number: "00901234",
    position: full_time_fisherman, nationality: "Malaysian", date_of_birth: Date.new(1995, 11, 2),
    gender: "Male", foreign_worker_license_no: "FWL000003", foreign_worker_license_start_date: Date.new(2026, 1, 1),
    foreign_worker_license_end_date: Date.new(2027, 1, 1), approve: false },
  { company_profile: commercial_profile, crew_name: "Faris bin Jamal", ic_number: "01234567",
    position: logistic_assistant, nationality: "Bruneian", date_of_birth: Date.new(1988, 7, 9),
    gender: "Male", foreign_worker_license_no: "FWL000004", foreign_worker_license_start_date: Date.new(2026, 1, 1),
    foreign_worker_license_end_date: Date.new(2027, 1, 1), approve: true },
  { company_profile: commercial_profile, crew_name: "Daniel Lim Wei Kiat", ic_number: "01345678",
    passport_number: "A12345678", position: part_time_fisherman, nationality: "Malaysian", gender: "Male",
    date_of_birth: Date.new(1991, 12, 18), foreign_worker_license_no: "FWL000005",
    foreign_worker_license_start_date: Date.new(2026, 1, 1),
    foreign_worker_license_end_date: Date.new(2027, 1, 1), approve: true },
  { company_profile: small_scale_company_profile, crew_name: "Captain Yusof bin Hamid", ic_number: "00678901",
    position: boat_captain, nationality: "Bruneian", date_of_birth: Date.new(1985, 9, 3), gender: "Male",
    foreign_worker_license_no: "FWL000000B", foreign_worker_license_start_date: Date.new(2026, 1, 1),
    foreign_worker_license_end_date: Date.new(2027, 1, 1), approve: true },
  { company_profile: small_scale_company_profile, crew_name: "Hafiz bin Matassan", ic_number: "01012345",
    position: full_time_fisherman, nationality: "Bruneian", date_of_birth: Date.new(1992, 3, 30),
    gender: "Male", foreign_worker_license_no: "FWL000006", foreign_worker_license_start_date: Date.new(2026, 1, 1),
    foreign_worker_license_end_date: Date.new(2027, 1, 1), approve: true },
  { company_profile: small_scale_company_profile, crew_name: "Azlan bin Salleh", ic_number: "01456789",
    position: part_time_fisherman, nationality: "Bruneian", date_of_birth: Date.new(1996, 4, 25),
    gender: "Male", foreign_worker_license_no: "FWL000007", foreign_worker_license_start_date: Date.new(2026, 1, 1),
    foreign_worker_license_end_date: Date.new(2027, 1, 1), approve: true }
].freeze

COMPANIES_CREWS.each do |attrs|
  attrs = attrs.dup
  approve = attrs.delete(:approve)
  company_profile = attrs.delete(:company_profile)

  crew = company_profile.companies_crews.find_or_create_by!(ic_number: attrs[:ic_number]) do |c|
    c.assign_attributes(attrs)
  end
  crew.approve!(actor: admin) if approve && crew.may_approve?
end

puts "Seeded #{CompaniesCrew.count} crew members (#{CompaniesCrew.approved.count} approved)"
