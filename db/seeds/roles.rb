ROLE_DEFINITIONS = {
  Role::DOFI_OFFICER => {
    name: "DoFi Officer",
    description: "Full access: profiling approval, manifest approval, catch verification, user management.",
    permission_codes: :all
  },
  Role::JETTY_MANAGER => {
    name: "Jetty Manager",
    description: "Port-level authority: manifest port-in/out approval, fisherman approval.",
    permission_codes: %w[
      dashboard.view
      manifest_list.view manifest_list.list
      manifest_approvals.view manifest_approvals.list manifest_approvals.approve manifest_approvals.amendment
      fisherman_approvals.view fisherman_approvals.list fisherman_approvals.approve fisherman_approvals.amendment
    ]
  },
  Role::FISHERMAN => {
    name: "Fisherman",
    description: "Own profile, manifest submission, catch report (via PWA); requires approval.",
    permission_codes: %w[
      dashboard.view
      manifest_list.view manifest_list.list manifest_list.delete
      manifest_form.view manifest_form.create
      manifest_expenses.view manifest_expenses.create manifest_expenses.update
      ports.list
      profiling.view profiling.create profiling.update
      zones.view zones.list
      fishing_gears.view fishing_gears.list
      companies_vessels.view companies_vessels.list companies_vessels.create
      companies_vessels.update companies_vessels.delete
      companies_crews.view companies_crews.list companies_crews.create
      companies_crews.update companies_crews.delete
      companies_captains.view companies_captains.list companies_captains.create
      companies_captains.update companies_captains.delete
      companies_fishing_gears.view companies_fishing_gears.list companies_fishing_gears.create
      companies_fishing_gears.update companies_fishing_gears.delete
      capture_reports.view capture_reports.list capture_reports.create capture_reports.update
      manifest_minor_fishermen.view manifest_minor_fishermen.create manifest_minor_fishermen.delete
    ]
  }
}.freeze

# Found by name (stable across this vocabulary change) rather than kind: a DB seeded before `kind`
# existed has these 3 rows with kind still nil, so finding by kind would miss them and attempt to
# create duplicates that collide with the existing name uniqueness constraint. Backfill kind after.
ROLE_DEFINITIONS.each do |kind, attrs|
  role = Role.find_or_create_by!(name: attrs[:name]) do |r|
    r.kind = kind
    r.description = attrs[:description]
  end
  role.update!(kind: kind) if role.kind != kind

  permissions = attrs[:permission_codes] == :all ? Permission.all : Permission.where(code: attrs[:permission_codes])
  role.permissions = permissions
end

puts "Seeded #{Role.count} roles"
