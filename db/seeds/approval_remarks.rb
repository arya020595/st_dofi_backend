APPROVAL_REMARKS = [
  { reference_id: "AR_001", name: "Incomplete account information" },
  { reference_id: "AR_002", name: "Information mismatch" },
  { reference_id: "AR_003", name: "Does not meet the requirements" }
].freeze

APPROVAL_REMARKS.each do |attrs|
  ApprovalRemark.find_or_create_by!(reference_id: attrs[:reference_id]) do |remark|
    remark.name = attrs[:name]
  end
end

puts "Seeded #{ApprovalRemark.count} approval remarks"
