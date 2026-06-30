FISHING_GEARS = [
  { reference_id: "FG-001", local_name: "Jaring Insang Hanyut", name: "Drift Gill Net", gear_type: "Net",
    unit: "Meter", size: 30.0, fee: 5.0 },
  { reference_id: "FG-002", local_name: "Rawai", name: "Longline", gear_type: "Line",
    unit: "Meter", size: 50.0, fee: 10.0 },
  { reference_id: "FG-003", local_name: "Pukat Tunda", name: "Trawler", gear_type: "Trawl",
    unit: "Meter", size: 30.0, fee: 15.0 },
  { reference_id: "FG-004", local_name: "Pukat Jerut", name: "Purse Seine", gear_type: "Net",
    unit: "Quantity", size: nil, fee: 5.0 }
].freeze

FISHING_GEARS.each do |attrs|
  FishingGear.find_or_create_by!(reference_id: attrs[:reference_id]) do |gear|
    gear.local_name = attrs[:local_name]
    gear.name = attrs[:name]
    gear.gear_type = attrs[:gear_type]
    gear.unit = attrs[:unit]
    gear.size = attrs[:size]
    gear.fee = attrs[:fee]
  end
end

puts "Seeded #{FishingGear.count} fishing gears"
