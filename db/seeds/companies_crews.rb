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

def crew_rows_for(definition, context)
  case definition[:code]
  when "commercial_1" then commercial_crew_rows(context)
  when "small_company_1" then small_company_crew_rows(context)
  else [generic_crew_row(definition, context)]
  end
end

def commercial_crew_rows(context)
  [
    captain_rosli_crew(context),
    jefri_crew(context),
    muhammad_aliff_crew(context),
    rizal_crew(context),
    faris_crew(context),
    daniel_lim_crew(context)
  ]
end

def small_company_crew_rows(context)
  [
    captain_yusof_crew(context),
    hafiz_crew(context),
    azlan_crew(context)
  ]
end

def captain_rosli_crew(context)
  crew_row(context, crew_name: "Captain Rosli bin Awang", ic_number: "00567890", position: :boat_captain,
                    nationality: "Bruneian", date_of_birth: Date.new(1978, 4, 12), license_no: "FWL000000")
end

def jefri_crew(context)
  crew_row(context, crew_name: "Jefri bin Osman", ic_number: "00789012", position: :full_time_fisherman,
                    nationality: "Bruneian", date_of_birth: Date.new(1990, 1, 15), license_no: "FWL000001")
end

def muhammad_aliff_crew(context)
  crew_row(context, crew_name: "Muhammad Aliff bin Rahman", ic_number: "00890123",
                    position: :ice_storage_assistant, nationality: "Bruneian",
                    date_of_birth: Date.new(1993, 6, 22), license_no: "FWL000002")
end

def rizal_crew(context)
  crew_row(context, crew_name: "Rizal bin Kassim", ic_number: "00901234", position: :full_time_fisherman,
                    nationality: "Malaysian", date_of_birth: Date.new(1995, 11, 2), license_no: "FWL000003")
end

def faris_crew(context)
  crew_row(context, crew_name: "Faris bin Jamal", ic_number: "01234567", position: :logistic_assistant,
                    nationality: "Bruneian", date_of_birth: Date.new(1988, 7, 9), license_no: "FWL000004")
end

def daniel_lim_crew(context)
  crew_row(context, crew_name: "Daniel Lim Wei Kiat", ic_number: "01345678", position: :part_time_fisherman,
                    nationality: "Malaysian", date_of_birth: Date.new(1991, 12, 18), license_no: "FWL000005",
                    passport_number: "A12345678")
end

def captain_yusof_crew(context)
  crew_row(context, crew_name: "Captain Yusof bin Hamid", ic_number: "00678901", position: :boat_captain,
                    nationality: "Bruneian", date_of_birth: Date.new(1985, 9, 3), license_no: "FWL000000B")
end

def hafiz_crew(context)
  crew_row(context, crew_name: "Hafiz bin Matassan", ic_number: "01012345", position: :full_time_fisherman,
                    nationality: "Bruneian", date_of_birth: Date.new(1992, 3, 30), license_no: "FWL000006")
end

def azlan_crew(context)
  crew_row(context, crew_name: "Azlan bin Salleh", ic_number: "01456789", position: :part_time_fisherman,
                    nationality: "Bruneian", date_of_birth: Date.new(1996, 4, 25), license_no: "FWL000007")
end

def generic_crew_row(definition, context)
  context.fetch(:generic_crew).call(
    definition,
    context.fetch(:company_profile),
    crew_name: "#{definition.dig(:owner, :full_name).split.first} Crew",
    ic_number: "#{definition.dig(:owner, :ic_no)[0, 6]}90",
    position: context.fetch(:generic_crew_position).call(definition),
    approve: definition[:review_state] != :pending_crew
  )
end

def crew_row(context, attributes)
  attributes.merge(
    company_profile: context.fetch(:company_profile),
    position: context.fetch(attributes.fetch(:position)),
    gender: "Male",
    foreign_worker_license_no: attributes.fetch(:license_no),
    foreign_worker_license_start_date: Date.new(2026, 1, 1),
    foreign_worker_license_end_date: Date.new(2027, 1, 1), approve: true
  ).except(:license_no)
end

crews_for = lambda do |definition|
  company_profile = profiles_by_code.fetch(definition[:code])
  crew_rows_for(definition, company_profile: company_profile, generic_crew: generic_crew,
                            generic_crew_position: generic_crew_position, boat_captain: boat_captain,
                            full_time_fisherman: full_time_fisherman, part_time_fisherman: part_time_fisherman,
                            ice_storage_assistant: ice_storage_assistant, logistic_assistant: logistic_assistant)
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
