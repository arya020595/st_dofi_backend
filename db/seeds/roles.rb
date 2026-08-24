# The Fisherman role has no entry here — there is no global Fisherman role. Each company gets its
# own "Owner" role, created on demand by Flow B provisioning. See db/seeds/profiled_users.rb for how
# the dev fixture fisherman users get theirs.
ROLE_DEFINITIONS = {
  Role::DOFI_OFFICER => {
    name: "DoFi Officer",
    description: "Full access: profiling approval, manifest approval, catch verification, user management.",
    permission_codes: :all
  },
  Role::JETTY_MANAGER => {
    name: "Jetty Manager",
    description: "Port-level authority: manifest list/detail and port-in/out approval actions only.",
    permission_codes: %w[
      manifest_list.view manifest_list.list
      manifest_approvals.view manifest_approvals.list manifest_approvals.approve manifest_approvals.amendment
    ]
  }
}.freeze

# Found by name (stable across this vocabulary change) rather than kind: a DB seeded before `kind`
# existed has these rows with kind still nil, so finding by kind would miss them and attempt to
# create duplicates that collide with the existing name uniqueness constraint. Backfill kind/
# platform_scope after.
ROLE_DEFINITIONS.each do |kind, attrs|
  role = Role.find_or_create_by!(name: attrs[:name]) do |r|
    r.kind = kind
    r.platform_scope = Role::DOFI_OFFICER_PLATFORM
    r.description = attrs[:description]
  end
  if role.kind != kind || role.platform_scope != Role::DOFI_OFFICER_PLATFORM
    role.update!(kind: kind, platform_scope: Role::DOFI_OFFICER_PLATFORM)
  end

  permissions = attrs[:permission_codes] == :all ? Permission.all : Permission.where(code: attrs[:permission_codes])
  role.permissions = permissions
end

puts "Seeded #{Role.count} roles"
