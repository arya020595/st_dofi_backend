POSITIONS = [
  { name: "Captain", category: "Jetty Manager" },
  { name: "Administrator", category: "DoFi Officer" },
  { name: "DoFi Officer", category: "DoFi Officer" },
  { name: "Boat Captain", category: "Fisherman" },
  { name: "Full-Time Fisherman", category: "Fisherman" },
  { name: "Part-Time Fisherman", category: "Fisherman" },
  { name: "Ice & Storage Assistant", category: "Fisherman" },
  { name: "Logistic Assistant", category: "Fisherman" }
].freeze

POSITIONS.each do |attrs|
  Position.find_or_create_by!(name: attrs[:name]) do |position|
    position.category = attrs[:category]
  end
end

puts "Seeded #{Position.count} positions"
