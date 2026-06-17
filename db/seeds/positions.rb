POSITIONS = ["Staff Crew", "Captain"].freeze

POSITIONS.each do |name|
  Position.find_or_create_by!(name: name)
end

puts "Seeded #{Position.count} positions"
