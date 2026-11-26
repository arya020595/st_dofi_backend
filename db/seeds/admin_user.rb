# The superadmin is a DoFi Officer, so (like every staff user) it has no password: it signs in with its Active
# Directory account. Its username must be that AD name ("mprt/<ad name>").
#   - development, test, staging: defaults to a mock account (any name works with the shared mock password).
#   - production: ADMIN_AD_USERNAME is required. Nothing is ever bootstrapped with a placeholder name there.
# An existing user is never modified (find_or_create_by! only runs the block on create); an already-seeded
# database is remapped with `bin/rails admin:assign_ad_username`.
officer_role = Role.find_by!(kind: Role::DOFI_OFFICER)

admin = User.find_or_create_by!(email: "admin@dofi.gov.bn") do |user|
  requested = ENV["ADMIN_AD_USERNAME"].to_s.strip.presence
  requested ||= "#{User::USERNAME_PREFIX}/DOF-001" unless Authentication::DirectoryConfig.current.production?
  short = Authentication::DirectoryUsername.new(requested, domain: User::USERNAME_PREFIX).short
  if short.nil?
    raise ArgumentError, "Set ADMIN_AD_USERNAME to the superadmin's real Active Directory username " \
                         "(letters, digits, '.', '_' or '-', optionally prefixed #{User::USERNAME_PREFIX}/)"
  end

  user.name = "DoFi Administrator"
  user.employee_id = "DOF-001"
  user.username = "#{User::USERNAME_PREFIX}/#{short}"
  user.position = "Administrator"
  user.unit = "Headquarters"
  user.role = officer_role
  user.status = "active"
  user.preferred_locale = "en"
end

puts "Seeded DoFi Officer admin user (admin@dofi.gov.bn, username #{admin.username})"
