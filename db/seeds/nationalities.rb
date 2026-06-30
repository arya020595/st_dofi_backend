NATIONALITIES = [
  { reference_id: "NT-001", code: "BN", name: "Bruneian" },
  { reference_id: "NT-002", code: "MY", name: "Malaysian" },
  { reference_id: "NT-003", code: "CN", name: "Chinese" },
  { reference_id: "NT-004", code: "PH", name: "Filipino" },
  { reference_id: "NT-005", code: "ID", name: "Indonesian" },
  { reference_id: "NT-006", code: "VN", name: "Vietnamese" },
  { reference_id: "NT-007", code: "IN", name: "Indian" },
  { reference_id: "NT-008", code: "TH", name: "Thai" }
].freeze

NATIONALITIES.each do |attrs|
  Nationality.find_or_create_by!(code: attrs[:code]) do |nationality|
    nationality.name = attrs[:name]
    nationality.reference_id = attrs[:reference_id]
  end
end

puts "Seeded #{Nationality.count} nationalities"
