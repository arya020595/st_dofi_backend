admin = User.find_by!(email: "admin@dofi.gov.bn")

boat_captain = Position.find_by!(name: "Boat Captain")
full_time_fisherman = Position.find_by!(name: "Full-Time Fisherman")
part_time_fisherman = Position.find_by!(name: "Part-Time Fisherman")
ice_storage_assistant = Position.find_by!(name: "Ice & Storage Assistant")
logistic_assistant = Position.find_by!(name: "Logistic Assistant")

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

generic_crew = lambda do |definition, company_profile, crew_name:, ic_number:, position:, approve:|
  birth_day_offset = ic_number[-2, 2].to_i

  {
    company_profile: company_profile,
    crew_name: crew_name,
    ic_number: ic_number,
    position: position,
    nationality: definition[:registration_type] == "Commercial" ? "Bruneian" : "Malaysian",
    date_of_birth: Date.new(1990, 1, 1) + birth_day_offset.days,
    gender: "Male",
    foreign_worker_license_no: "FWL-#{ic_number}",
    foreign_worker_license_start_date: Date.new(2026, 1, 1),
    foreign_worker_license_end_date: Date.new(2027, 1, 1),
    status: "active",
    approve: approve
  }
end

generic_crew_position = lambda do |definition|
  if definition[:registration_type] == "Commercial"
    boat_captain
  elsif definition[:registration_type].include?("Part-Time")
    part_time_fisherman
  else
    full_time_fisherman
  end
end

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/ParameterLists
def crew_rows_for(definition, company_profile, generic_crew, generic_crew_position, boat_captain, full_time_fisherman,
                  part_time_fisherman, ice_storage_assistant, logistic_assistant)
  case definition[:code]
  when "commercial_1"
    [
      { company_profile:, crew_name: "Captain Rosli bin Awang", ic_number: "00567890", position: boat_captain,
        nationality: "Bruneian", date_of_birth: Date.new(1978, 4, 12), gender: "Male",
        foreign_worker_license_no: "FWL000000", foreign_worker_license_start_date: Date.new(2026, 1, 1),
        foreign_worker_license_end_date: Date.new(2027, 1, 1), approve: true },
      { company_profile:, crew_name: "Jefri bin Osman", ic_number: "00789012", position: full_time_fisherman,
        nationality: "Bruneian", date_of_birth: Date.new(1990, 1, 15), gender: "Male",
        foreign_worker_license_no: "FWL000001", foreign_worker_license_start_date: Date.new(2026, 1, 1),
        foreign_worker_license_end_date: Date.new(2027, 1, 1), approve: true },
      { company_profile:, crew_name: "Muhammad Aliff bin Rahman", ic_number: "00890123",
        position: ice_storage_assistant, nationality: "Bruneian", date_of_birth: Date.new(1993, 6, 22),
        gender: "Male", foreign_worker_license_no: "FWL000002",
        foreign_worker_license_start_date: Date.new(2026, 1, 1),
        foreign_worker_license_end_date: Date.new(2027, 1, 1), approve: true },
      { company_profile:, crew_name: "Rizal bin Kassim", ic_number: "00901234", position: full_time_fisherman,
        nationality: "Malaysian", date_of_birth: Date.new(1995, 11, 2), gender: "Male",
        foreign_worker_license_no: "FWL000003", foreign_worker_license_start_date: Date.new(2026, 1, 1),
        foreign_worker_license_end_date: Date.new(2027, 1, 1), approve: true },
      { company_profile:, crew_name: "Faris bin Jamal", ic_number: "01234567", position: logistic_assistant,
        nationality: "Bruneian", date_of_birth: Date.new(1988, 7, 9), gender: "Male",
        foreign_worker_license_no: "FWL000004", foreign_worker_license_start_date: Date.new(2026, 1, 1),
        foreign_worker_license_end_date: Date.new(2027, 1, 1), approve: true },
      { company_profile:, crew_name: "Daniel Lim Wei Kiat", ic_number: "01345678", passport_number: "A12345678",
        position: part_time_fisherman, nationality: "Malaysian", gender: "Male", date_of_birth: Date.new(1991, 12, 18),
        foreign_worker_license_no: "FWL000005", foreign_worker_license_start_date: Date.new(2026, 1, 1),
        foreign_worker_license_end_date: Date.new(2027, 1, 1), approve: true }
    ]
  when "small_company_1"
    [
      { company_profile:, crew_name: "Captain Yusof bin Hamid", ic_number: "00678901", position: boat_captain,
        nationality: "Bruneian", date_of_birth: Date.new(1985, 9, 3), gender: "Male",
        foreign_worker_license_no: "FWL000000B", foreign_worker_license_start_date: Date.new(2026, 1, 1),
        foreign_worker_license_end_date: Date.new(2027, 1, 1), approve: true },
      { company_profile:, crew_name: "Hafiz bin Matassan", ic_number: "01012345", position: full_time_fisherman,
        nationality: "Bruneian", date_of_birth: Date.new(1992, 3, 30), gender: "Male",
        foreign_worker_license_no: "FWL000006", foreign_worker_license_start_date: Date.new(2026, 1, 1),
        foreign_worker_license_end_date: Date.new(2027, 1, 1), approve: true },
      { company_profile:, crew_name: "Azlan bin Salleh", ic_number: "01456789", position: part_time_fisherman,
        nationality: "Bruneian", date_of_birth: Date.new(1996, 4, 25), gender: "Male",
        foreign_worker_license_no: "FWL000007", foreign_worker_license_start_date: Date.new(2026, 1, 1),
        foreign_worker_license_end_date: Date.new(2027, 1, 1), approve: true }
    ]
  else
    [
      generic_crew.call(
        definition,
        company_profile,
        crew_name: "#{definition.dig(:owner, :full_name).split.first} Crew",
        ic_number: "#{definition.dig(:owner, :ic_no)[0, 6]}90",
        position: generic_crew_position.call(definition),
        approve: definition[:review_state] != :pending_crew
      )
    ]
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/ParameterLists

crews_for = lambda do |definition|
  company_profile = profiles_by_code.fetch(definition[:code])
  crew_rows_for(definition, company_profile, generic_crew, generic_crew_position, boat_captain, full_time_fisherman,
                part_time_fisherman, ice_storage_assistant, logistic_assistant)
end

companies_crews = []

SEED_COMPANY_PROFILES.each do |definition|
  companies_crews.concat(
    crews_for.call(definition)
  )
end

companies_crews.each do |attrs|
  attrs = attrs.dup
  approve = attrs.delete(:approve)
  company_profile = attrs.delete(:company_profile)

  crew = company_profile.companies_crews.find_or_create_by!(ic_number: attrs[:ic_number]) do |record|
    record.assign_attributes(attrs)
  end
  crew.update!(attrs)
  apply_approval_state.call(crew, approve)
end

puts "Seeded #{CompaniesCrew.count} crew members (#{CompaniesCrew.approved.count} approved)"
