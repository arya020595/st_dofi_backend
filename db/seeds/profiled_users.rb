jetty_manager_role = Role.find_by!(kind: Role::JETTY_MANAGER)
default_password = ENV.fetch("ADMIN_DEFAULT_PASSWORD", "ChangeMe123!")

# Every Owner/Admin CompanyProfileContact from company_profiles.rb gets the same user the real
# CompanyProfiles::Create flow provisions: the company's Owner/Admin role by designation, the
# dofi_company_profile provisioning source, and a claimable fisherman status. The ICs below are the
# exception: already claimed and BruneiID-verified so they can log in via mock BruneiID without
# going through the claim step. Re-running converges existing rows (role, source, status) and never
# resets a user who has really claimed a different, non-listed identity.
CLAIMED_FISHERMAN_ICS = %w[00-100035 01-234567 51-345678 51-456789 51-567892].freeze

def fisherman_role_for(contact)
  case contact.designation
  when "Owner" then Roles::EnsureFishermanOwnerRole.call(contact.company_profile)
  when "Admin" then Roles::EnsureFishermanAdminRole.call(contact.company_profile)
  end
end

def claimed_fisherman_ic?(contact)
  CLAIMED_FISHERMAN_ICS.include?(contact.ic_no)
end

def active_fisherman_user?(user)
  user.persisted? && user.fisherman_status == "active"
end

def contact_user_identity_attributes(contact, role)
  {
    name: contact.full_name,
    role: role,
    registration_type: contact.company_profile.registration_type,
    company_profile: contact.company_profile,
    company_profile_contact: contact,
    designation: contact.designation
  }
end

def contact_user_status_attributes(contact, user)
  base = { status: "active", provisioning_source: Fisherman::ProvisionUser::DOFI_COMPANY_PROFILE,
           preferred_locale: "en" }
  return base.merge(fisherman_status: "claimable", claimed_at: nil, brunei_id_verified_at: nil) unless
    claimed_fisherman_ic?(contact)

  seeded_at = Time.current
  base.merge(fisherman_status: "active", claimed_at: user.claimed_at || seeded_at,
             brunei_id_verified_at: user.brunei_id_verified_at || seeded_at)
end

def assign_seed_password!(user, default_password)
  return unless user.new_record?

  user.password = default_password
  user.password_confirmation = default_password
end

def seed_company_contact_user!(contact, default_password)
  role = fisherman_role_for(contact)
  return if role.blank?

  role.permissions = Permission.assignable_to(Role::FISHERMAN_PLATFORM)
  user = User.find_or_initialize_by(ic_number: contact.ic_no)
  return if active_fisherman_user?(user) && !claimed_fisherman_ic?(contact)

  user.assign_attributes(contact_user_identity_attributes(contact, role)
                           .merge(contact_user_status_attributes(contact, user)))
  assign_seed_password!(user, default_password)
  user.save!
end

SEED_COMPANY_PROFILES.each do |definition|
  profile = CompanyProfile.find_by!(
    registration_type: definition[:registration_type],
    fisherman_card_no: definition[:fisherman_card_no]
  )

  profile.contacts.kept.find_each { |contact| seed_company_contact_user!(contact, default_password) }
end

JETTY_MANAGER_USERS = [
  { name: "Encik Mahmud bin Taha", ic_number: "31-567891", unit: "Serasa Port", position: "Jetty Manager",
    contact_no: "+673 7123456" }
].freeze

JETTY_MANAGER_USERS.each do |attrs|
  jetty_manager = User.find_or_initialize_by(ic_number: attrs[:ic_number])
  jetty_manager.assign_attributes(
    name: attrs[:name],
    role: jetty_manager_role,
    unit: attrs[:unit],
    position: attrs[:position],
    contact_no: attrs[:contact_no],
    status: "active",
    fisherman_status: nil,
    provisioning_source: nil,
    preferred_locale: "en",
    brunei_id_verified_at: Time.current
  )
  unless jetty_manager.persisted?
    jetty_manager.password = default_password
    jetty_manager.password_confirmation = default_password
  end
  jetty_manager.save!
end

fisherman_count = User.joins(:role).where(roles: { platform_scope: Role::FISHERMAN_PLATFORM }).count
puts "Seeded #{fisherman_count} fisherman users and " \
     "#{User.where(role: jetty_manager_role).count} jetty manager users"
