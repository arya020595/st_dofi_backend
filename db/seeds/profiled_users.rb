fisherman_role = Role.find_by!(kind: Role::FISHERMAN)
jetty_manager_role = Role.find_by!(kind: Role::JETTY_MANAGER)
default_password = ENV.fetch("ADMIN_DEFAULT_PASSWORD", "ChangeMe123!")

# Matched to the Owner/Admin CompanyProfileContact rows from company_profiles.rb by ic_number — same
# match Users::RegisterFisherman performs — so these accounts are ready to log in via mock BruneiID
# (see docs/registration/testing-mock-brunei-id-login.md) without going through self-registration first.
FISHERMAN_USERS = [
  { name: "Haji Ahmad bin Salleh", ic_number: "00123456", registration_type: "Commercial" },
  { name: "Siti Aminah binti Yusof", ic_number: "00234567", registration_type: "Commercial" },
  { name: "Awang Zulkifli bin Hashim", ic_number: "00345678", registration_type: "Small-Scale (Company)" },
  { name: "Dayang Norhayati binti Tuah", ic_number: "00456789", registration_type: "Small - Scale (Full-Time)" }
].freeze

FISHERMAN_USERS.each do |attrs|
  contact = CompanyProfileContact.find_by!(ic_no: attrs[:ic_number])

  User.find_or_create_by!(ic_number: attrs[:ic_number]) do |user|
    user.name = attrs[:name]
    user.role = fisherman_role
    user.registration_type = attrs[:registration_type]
    user.company_profile = contact.company_profile
    user.company_profile_contact = contact
    user.designation = contact.designation
    user.status = "active"
    user.preferred_locale = "en"
    user.brunei_id_verified_at = Time.current
    user.password = default_password
    user.password_confirmation = default_password
  end
end

JETTY_MANAGER_USERS = [
  { name: "Encik Mahmud bin Taha", ic_number: "00567891", unit: "Serasa Port", position: "Jetty Manager",
    contact_no: "+673 7123456" }
].freeze

JETTY_MANAGER_USERS.each do |attrs|
  User.find_or_create_by!(ic_number: attrs[:ic_number]) do |user|
    user.name = attrs[:name]
    user.role = jetty_manager_role
    user.unit = attrs[:unit]
    user.position = attrs[:position]
    user.contact_no = attrs[:contact_no]
    user.status = "active"
    user.preferred_locale = "en"
    user.brunei_id_verified_at = Time.current
    user.password = default_password
    user.password_confirmation = default_password
  end
end

puts "Seeded #{User.where(role: fisherman_role).count} fisherman users and " \
     "#{User.where(role: jetty_manager_role).count} jetty manager users"
