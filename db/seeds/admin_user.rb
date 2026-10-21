officer_role = Role.find_by!(kind: Role::DOFI_OFFICER)
default_password = ENV.fetch("ADMIN_DEFAULT_PASSWORD", "ChangeMe123!")
default_username = ENV.fetch("ADMIN_DEFAULT_USERNAME", "#{User::USERNAME_PREFIX}/DOF-001")

admin = User.find_or_create_by!(email: "admin@dofi.gov.bn") do |user|
  user.name = "DoFi Administrator"
  user.employee_id = "DOF-001"
  user.username = default_username
  user.position = "Administrator"
  user.unit = "Headquarters"
  user.role = officer_role
  user.status = "active"
  user.preferred_locale = "en"
  user.password = default_password
  user.password_confirmation = default_password
end

# find_or_create_by! only sets the block's attributes when *creating* — an admin row seeded before
# `username`/`position`/`unit` were required would otherwise stay blank forever on every later
# `db:seed` re-run. Backfill any that are still blank in a single update — the officer validation
# (see User#validates :position, :unit, :username, presence: true, if: :officer?) requires all
# three at once, so updating them one at a time would fail on a row missing more than one.
backfill = {}
backfill[:username] = default_username if admin.username.blank?
backfill[:position] = "Administrator" if admin.position.blank?
backfill[:unit] = "Headquarters" if admin.unit.blank?
admin.update!(backfill) if backfill.any?

puts "Seeded default DoFi Officer admin user (admin@dofi.gov.bn)"
