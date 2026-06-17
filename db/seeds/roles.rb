ROLE_DEFINITIONS = {
  "ROLE-001" => {
    name: "DoFi Officer",
    description: "Full access: profiling approval, manifest approval, catch verification, user management.",
    permission_codes: :all
  },
  "ROLE-002" => {
    name: "Jetty Manager",
    description: "Port-level authority: manifest port-in/out approval, fisherman approval.",
    permission_codes: %w[
      dashboard.view
      manifest_list.view manifest_list.list
      manifest_approvals.view manifest_approvals.list manifest_approvals.approve manifest_approvals.amendment
      fisherman_approvals.view fisherman_approvals.list fisherman_approvals.approve fisherman_approvals.amendment
    ]
  },
  "ROLE-003" => {
    name: "Fisherman",
    description: "Own profile, manifest submission, catch report (via PWA); requires approval.",
    permission_codes: %w[
      dashboard.view
      manifest_list.view manifest_list.list
      manifest_form.view manifest_form.create
      profiling.view profiling.create profiling.update
    ]
  }
}.freeze

ROLE_DEFINITIONS.each do |reference_id, attrs|
  role = Role.find_or_create_by!(reference_id: reference_id) do |r|
    r.name = attrs[:name]
    r.description = attrs[:description]
  end

  permissions = attrs[:permission_codes] == :all ? Permission.all : Permission.where(code: attrs[:permission_codes])
  role.permissions = permissions
end

puts "Seeded #{Role.count} roles"
