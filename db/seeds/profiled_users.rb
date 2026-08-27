jetty_manager_role = Role.find_by!(kind: Role::JETTY_MANAGER)
default_password = ENV.fetch("ADMIN_DEFAULT_PASSWORD", "ChangeMe123!")
dofi_officer = User.find_by(role: Role.find_by(kind: Role::DOFI_OFFICER))

# Matched to the Owner/Admin CompanyProfileContact rows from company_profiles.rb by ic_number so
# these accounts are ready to log in via mock BruneiID without Fisherman self-registration.
FISHERMAN_USERS = [
  { name: "Haji Ahmad bin Salleh", ic_number: "01-123456", registration_type: "Commercial" },
  { name: "Siti Aminah binti Yusof", ic_number: "01-234567", registration_type: "Commercial" },
  { name: "Awang Zulkifli bin Hashim", ic_number: "51-345678", registration_type: "Small-Scale (Company)" },
  { name: "Dayang Norhayati binti Tuah", ic_number: "51-456789", registration_type: "Small - Scale (Full-Time)" },
  { name: "Osman bin Haji Rosli", ic_number: "51-567892", registration_type: "Small - Scale (Part-Time)" }
].freeze

FISHERMAN_USERS.each do |attrs|
  contact = CompanyProfileContact.find_by!(ic_no: attrs[:ic_number])

  # Each fixture user belongs to a different company_profile (see db/seeds/company_profiles.rb), so
  # each needs its own company-scoped Owner role, not a single shared role like the old global
  # Fisherman kind row.
  owner_role = Roles::EnsureFishermanOwnerRole.call(contact.company_profile)
  owner_role.permissions = Permission.assignable_to(Role::FISHERMAN_PLATFORM)
  seeded_at = Time.current

  User.find_or_create_by!(ic_number: attrs[:ic_number]) do |user|
    user.name = attrs[:name]
    user.role = owner_role
    user.registration_type = attrs[:registration_type]
    user.company_profile = contact.company_profile
    user.company_profile_contact = contact
    user.designation = contact.designation
    user.status = "active"
    user.fisherman_status = "active"
    user.provisioning_source = Fisherman::ProvisionUser::DOFI_COMPANY_PROFILE
    user.approved_at = seeded_at
    user.approved_by = dofi_officer
    user.claimed_at = seeded_at
    user.preferred_locale = "en"
    user.brunei_id_verified_at = seeded_at
    user.password = default_password
    user.password_confirmation = default_password
  end
end

def pending_review_state?(review_state)
  review_state != :approved
end

def pending_fisherman_role_for(contact)
  case contact.designation
  when "Owner" then Roles::EnsureFishermanOwnerRole.call(contact.company_profile)
  when "Admin" then Roles::EnsureFishermanAdminRole.call(contact.company_profile)
  end
end

def active_fisherman_user?(user)
  user.persisted? && user.fisherman_status == "active"
end

def pending_profile_identity_attributes(contact, role)
  {
    name: contact.full_name,
    role: role,
    registration_type: contact.company_profile.registration_type,
    company_profile: contact.company_profile,
    company_profile_contact: contact,
    designation: contact.designation
  }
end

def pending_profile_status_attributes
  {
    status: "active",
    fisherman_status: "pending_approval",
    provisioning_source: Fisherman::ProvisionUser::DOFI_COMPANY_PROFILE,
    approved_at: nil,
    approved_by: nil,
    claimed_at: nil,
    preferred_locale: "en",
    brunei_id_verified_at: nil
  }
end

def pending_profile_user_attributes(contact, role)
  pending_profile_identity_attributes(contact, role).merge(pending_profile_status_attributes)
end

def assign_seed_password!(user, default_password)
  return unless user.new_record?

  user.password = default_password
  user.password_confirmation = default_password
end

def seed_pending_profile_contact_user!(contact, default_password)
  role = pending_fisherman_role_for(contact)
  return if role.blank?

  role.permissions = Permission.assignable_to(Role::FISHERMAN_PLATFORM)
  user = User.find_or_initialize_by(ic_number: contact.ic_no)
  return if active_fisherman_user?(user)

  user.assign_attributes(pending_profile_user_attributes(contact, role))
  assign_seed_password!(user, default_password)
  user.save!
end

SEED_COMPANY_PROFILES.select { |definition| pending_review_state?(definition[:review_state]) }.each do |definition|
  profile = CompanyProfile.find_by!(
    registration_type: definition[:registration_type],
    fisherman_card_no: definition[:fisherman_card_no]
  )

  profile.contacts.kept.find_each do |contact|
    seed_pending_profile_contact_user!(contact, default_password)
  end
end

JETTY_MANAGER_USERS = [
  { name: "Encik Mahmud bin Taha", ic_number: "31-567891", unit: "Serasa Port", position: "Jetty Manager",
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

fisherman_count = User.joins(:role).where(roles: { platform_scope: Role::FISHERMAN_PLATFORM }).count
puts "Seeded #{fisherman_count} fisherman users and " \
     "#{User.where(role: jetty_manager_role).count} jetty manager users"
