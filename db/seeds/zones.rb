ZONES = [
  { name: "Zone 1A Keatas", zone_type: "Inshore", start_range: "0 Nm", end_range: "3 Nm" },
  { name: "Zone 2 Keatas", zone_type: "Inshore", start_range: "3 Nm", end_range: "20 Nm" },
  { name: "Zone 3", zone_type: "Offshore", start_range: "20 Nm", end_range: "45 Nm" },
  { name: "Zone 4", zone_type: "Deep Sea", start_range: "45 Nm", end_range: "200 Nm" }
].freeze

ZONES.each do |attrs|
  Zone.find_or_create_by!(name: attrs[:name]) do |zone|
    zone.zone_type = attrs[:zone_type]
    zone.start_range = attrs[:start_range]
    zone.end_range = attrs[:end_range]
  end
end

puts "Seeded #{Zone.count} zones"
