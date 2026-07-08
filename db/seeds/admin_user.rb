officer_role = Role.find_by!(reference_id: "ROLE-001")
default_password = ENV.fetch("ADMIN_DEFAULT_PASSWORD", "ChangeMe123!")

User.find_or_create_by!(email: "admin@dofi.gov.bn") do |user|
  user.name = "DoFi Administrator"
  user.employee_id = "DOF-001"
  user.role = officer_role
  user.status = "active"
  user.preferred_locale = "en"
  user.password = default_password
  user.password_confirmation = default_password
end

puts "Seeded default DoFi Officer admin user (admin@dofi.gov.bn)"
