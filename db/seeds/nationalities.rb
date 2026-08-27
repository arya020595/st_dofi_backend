Nationality.reset_column_information

NATIONALITIES = [
  { code: "BN", name: "Bruneian", is_local_citizenship: true },
  { code: "MY", name: "Malaysian" },
  { code: "CN", name: "Chinese" },
  { code: "PH", name: "Filipino" },
  { code: "ID", name: "Indonesian" },
  { code: "VN", name: "Vietnamese" },
  { code: "IN", name: "Indian" },
  { code: "TH", name: "Thai" }
].freeze

NATIONALITIES.each do |attrs|
  nationality = Nationality.find_or_initialize_by(code: attrs[:code])
  nationality.name = attrs[:name]
  nationality.is_local_citizenship = attrs.fetch(:is_local_citizenship, false)
  nationality.save!
end

puts "Seeded #{Nationality.count} nationalities"
