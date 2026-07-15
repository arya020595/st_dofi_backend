SKIP_REASONS = [
  { name: "No Fish Caught" },
  { name: "Engine Issue" },
  { name: "Emergency Recall" },
  { name: "Bad Weather Conditions" },
  { name: "Rough Sea Conditions" },
  { name: "Other" }
].freeze

SKIP_REASONS.each do |attrs|
  ManifestSkipReason.find_or_create_by!(name: attrs[:name])
end

# Earlier seed wording ("No fish caught", "Engine malfunction", "Bad weather", "Other (see
# remarks)") predates the Manifest module's finalized skip-reason list — discard any leftover rows
# from that wording rather than leaving them selectable alongside the current list.
stale_names = ["No fish caught", "Engine malfunction", "Bad weather", "Other (see remarks)"]
ManifestSkipReason.kept.where(name: stale_names).find_each(&:discard!)

puts "Seeded #{ManifestSkipReason.kept.count} skip reasons"
