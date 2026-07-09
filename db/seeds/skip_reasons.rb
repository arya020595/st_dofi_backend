SKIP_REASONS = [
  { name: "No fish caught" },
  { name: "Engine malfunction" },
  { name: "Bad weather" },
  { name: "Other (see remarks)" }
].freeze

SKIP_REASONS.each do |attrs|
  ManifestSkipReason.find_or_create_by!(name: attrs[:name])
end

puts "Seeded #{ManifestSkipReason.count} skip reasons"
