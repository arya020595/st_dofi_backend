FactoryBot.define do
  factory :company_profile do
    sequence(:reference_id) { |n| "REG-DOF-#{n}" }
    registration_type { "Commercial" }
    company_name { "Azri Fish Sdn Bhd" }
    company_address { "Spg 10, Pantai Serasa, Mukim Serasa" }
    rocbn_no { "RC20390923" }
    contact_no { "71111111" }
    district { "Brunei - Muara" }
    mukim { "Serasa" }
    village { "Kapok" }
    sequence(:fisherman_card_no) { |n| "R-2026-#{format('%06d', n)}" }
    issue_date { Date.new(2026, 1, 1) }
    license_expiry_date { Date.new(2026, 12, 31) }
    worker_quota { 34 }
    full_name { "Muhammad Shahrizan Bin Haji Said" }
    gender { "Male" }
    ic_colour { "Yellow" }
    designation { "Owner" }
    sequence(:ic_no) { |n| format("01-%06d", n) }
  end
end
