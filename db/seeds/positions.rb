POSITIONS = [
  { name: "Crew", category: "Fisherman" },
  { name: "Captain", category: "Jetty Manager" },
  { name: "Administrator", category: "DoFi Officer" },
  { name: "DoFi Officer", category: "DoFi Officer" }
].freeze

POSITIONS.each do |attrs|
  Position.find_or_create_by!(name: attrs[:name]) do |position|
    position.category = attrs[:category]
  end
end

puts "Seeded #{Position.count} positions"
