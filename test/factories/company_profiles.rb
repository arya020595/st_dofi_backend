FactoryBot.define do
  factory :company_profile do
    sequence(:reference_id) { |n| "REG-DOF-#{n}" }
    registration_type { "Commercial" }
    company_name { "Azri Fish Sdn Bhd" }
    rocbn_no { "RC20390923" }
    full_name { "Muhammad Shahrizan Bin Haji Said" }
    sequence(:ic_no) { |n| format("01-%06d", n) }
  end
end
