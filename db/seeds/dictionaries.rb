# Starter set of common Brunei fish species. Extend with the full species
# list via the Dictionary admin UI / bulk import once that is built.
DICTIONARIES = [
  { reference_id: "SP-0001", local_name: "Ikan Tenggiri", scientific_name: "Scomberomorus commerson",
    group_name: "Pelagic Fish", family_name: "Scombridae" },
  { reference_id: "SP-0002", local_name: "Ikan Kembung", scientific_name: "Rastrelliger kanagurta",
    group_name: "Pelagic Fish", family_name: "Scombridae" },
  { reference_id: "SP-0003", local_name: "Ikan Merah", scientific_name: "Lutjanus campechanus",
    group_name: "Demersal Fish", family_name: "Lutjanidae" },
  { reference_id: "SP-0004", local_name: "Ikan Bawal Putih", scientific_name: "Pampus argenteus",
    group_name: "Demersal Fish", family_name: "Stromateidae" },
  { reference_id: "SP-0005", local_name: "Ikan Selar", scientific_name: "Selaroides leptolepis",
    group_name: "Pelagic Fish", family_name: "Carangidae" },
  { reference_id: "SP-0006", local_name: "Udang Harimau", scientific_name: "Penaeus monodon",
    group_name: "Crustacean", family_name: "Penaeidae" },
  { reference_id: "SP-0007", local_name: "Sotong", scientific_name: "Loligo spp.",
    group_name: "Cephalopod", family_name: "Loliginidae" },
  { reference_id: "SP-0008", local_name: "Ikan Pari", scientific_name: "Himantura spp.",
    group_name: "Demersal Fish", family_name: "Dasyatidae" },
  { reference_id: "SP-0009", local_name: "Ikan Tongkol", scientific_name: "Euthynnus affinis",
    group_name: "Pelagic Fish", family_name: "Scombridae" },
  { reference_id: "SP-0010", local_name: "Ikan Kerapu", scientific_name: "Epinephelus spp.",
    group_name: "Demersal Fish", family_name: "Serranidae" }
].freeze

DICTIONARIES.each do |attrs|
  Dictionary.find_or_create_by!(reference_id: attrs[:reference_id]) do |dictionary|
    dictionary.local_name = attrs[:local_name]
    dictionary.scientific_name = attrs[:scientific_name]
    dictionary.group_name = attrs[:group_name]
    dictionary.family_name = attrs[:family_name]
  end
end

puts "Seeded #{Dictionary.count} fish species"
