FISHING_GEARS = [
  { reference_id: "FG-001", name: "Drift Gill Net", gear_type: "Net", gear_specification: "30m" },
  { reference_id: "FG-002", name: "Longline", gear_type: "Line", gear_specification: "500m" },
  { reference_id: "FG-003", name: "Trawler", gear_type: "Trawl", gear_specification: nil },
  { reference_id: "FG-004", name: "Purse Seine", gear_type: "Net", gear_specification: nil }
].freeze

FISHING_GEARS.each do |attrs|
  FishingGear.find_or_create_by!(reference_id: attrs[:reference_id]) do |gear|
    gear.name = attrs[:name]
    gear.gear_type = attrs[:gear_type]
    gear.gear_specification = attrs[:gear_specification]
  end
end

puts "Seeded #{FishingGear.count} fishing gears"
