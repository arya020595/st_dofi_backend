FactoryBot.define do
  factory :fish_capture_detail do
    capture_report
    dictionary
    price_per_kg { 10.0 }
    amount_captured_kg { 5.0 }
    overall_total { 50.0 }
  end
end
