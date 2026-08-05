FactoryBot.define do
  factory :manifest_expense do
    manifest
    fuel_litres { 50.0 }
    fuel_bnd { 75.0 }
  end
end

# == Schema Information
#
# Table name: manifest_expenses
# Database name: primary
#
#  id          :uuid             not null, primary key
#  fuel_bnd    :decimal(10, 2)
#  fuel_litres :decimal(10, 2)
#  ice_bnd     :decimal(10, 2)
#  ice_litres  :decimal(10, 2)
#  ration_bnd  :decimal(10, 2)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  manifest_id :uuid             not null
#
# Indexes
#
#  index_manifest_expenses_on_manifest_id  (manifest_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (manifest_id => manifests.id)
#
