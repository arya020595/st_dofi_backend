POSITIONS = [
  { reference_id: "POS-001", name: "Crew", category: "Fisherman" },
  { reference_id: "POS-002", name: "Captain", category: "Jetty Manager" }
].freeze

POSITIONS.each do |attrs|
  Position.find_or_create_by!(name: attrs[:name]) do |position|
    position.reference_id = attrs[:reference_id]
    position.category = attrs[:category]
  end
end

puts "Seeded #{Position.count} positions"
