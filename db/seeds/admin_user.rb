officer_role = Role.find_by!(reference_id: "ROLE-001")
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
# `db:seed` re-run.
admin.update!(username: default_username) if admin.username.blank?
admin.update!(position: "Administrator") if admin.position.blank?
admin.update!(unit: "Headquarters") if admin.unit.blank?

puts "Seeded default DoFi Officer admin user (admin@dofi.gov.bn)"
