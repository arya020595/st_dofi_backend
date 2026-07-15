FactoryBot.define do
  factory :capture_report_expense do
    capture_report
    fuel_litres { 50.0 }
    fuel_bnd { 75.0 }
  end
end
