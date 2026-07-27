FactoryBot.define do
  factory :manifest_expense do
    manifest
    fuel_litres { 50.0 }
    fuel_bnd { 75.0 }
  end
end
