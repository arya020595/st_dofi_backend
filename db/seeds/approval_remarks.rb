APPROVAL_REMARKS = [
  { name: "Incomplete account information" },
  { name: "Information mismatch" },
  { name: "Does not meet the requirements" }
].freeze

APPROVAL_REMARKS.each do |attrs|
  ApprovalRemark.find_or_create_by!(name: attrs[:name])
end

puts "Seeded #{ApprovalRemark.count} approval remarks"
