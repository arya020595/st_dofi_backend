NATIONALITIES = [
  { code: "BN", name: "Bruneian" },
  { code: "MY", name: "Malaysian" },
  { code: "CN", name: "Chinese" },
  { code: "PH", name: "Filipino" },
  { code: "ID", name: "Indonesian" },
  { code: "VN", name: "Vietnamese" },
  { code: "IN", name: "Indian" },
  { code: "TH", name: "Thai" }
].freeze

NATIONALITIES.each do |attrs|
  Nationality.find_or_create_by!(code: attrs[:code]) do |nationality|
    nationality.name = attrs[:name]
  end
end

puts "Seeded #{Nationality.count} nationalities"
