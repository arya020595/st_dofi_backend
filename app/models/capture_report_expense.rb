class CaptureReportExpense < ApplicationRecord
  belongs_to :capture_report

  def self.ransackable_attributes(_auth_object = nil)
    %w[id capture_report_id fuel_litres fuel_bnd ice_litres ice_bnd ration_bnd created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
