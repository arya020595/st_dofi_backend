FactoryBot.define do
  factory :company_profile_contact do
    company_profile
    full_name { "Muhammad Shahrizan Bin Haji Said" }
    gender { "Male" }
    ic_colour { "Yellow" }
    designation { "Owner" }
    sequence(:ic_no) { |n| format("01-%06d", n) }
  end
end
