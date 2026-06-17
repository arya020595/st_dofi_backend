PORTS = [
  { reference_id: "PT-001", port_name: "Serasa Port", latitude: 5.034722, longitude: 115.072222 },
  { reference_id: "PT-002", port_name: "Muara International Fish Landing (MIFL)", latitude: 5.020556,
    longitude: 115.073889 },
  { reference_id: "PT-003", port_name: "Lumut Port", latitude: 4.633333, longitude: 114.883333 }
].freeze

PORTS.each do |attrs|
  Port.find_or_create_by!(reference_id: attrs[:reference_id]) do |port|
    port.port_name = attrs[:port_name]
    port.latitude = attrs[:latitude]
    port.longitude = attrs[:longitude]
  end
end

puts "Seeded #{Port.count} ports"
