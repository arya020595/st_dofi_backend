SKIP_REASONS = [
  { reference_id: "REA-001", name: "No fish caught" },
  { reference_id: "REA-002", name: "Engine malfunction" },
  { reference_id: "REA-003", name: "Bad weather" },
  { reference_id: "REA-004", name: "Other (see remarks)" }
].freeze

SKIP_REASONS.each do |attrs|
  ManifestSkipReason.find_or_create_by!(reference_id: attrs[:reference_id]) do |reason|
    reason.name = attrs[:name]
  end
end

puts "Seeded #{ManifestSkipReason.count} skip reasons"
