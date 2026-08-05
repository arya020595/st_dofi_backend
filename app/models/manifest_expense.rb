class ManifestExpense < ApplicationRecord
  belongs_to :manifest

  def self.ransackable_attributes(_auth_object = nil)
    %w[id manifest_id fuel_litres fuel_bnd ice_litres ice_bnd ration_bnd created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
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
