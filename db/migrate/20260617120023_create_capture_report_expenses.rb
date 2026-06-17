class CreateCaptureReportExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :capture_report_expenses, id: :uuid do |t|
      t.references :capture_report, null: false, foreign_key: true, type: :uuid, index: false
      t.decimal :fuel_litres, precision: 10, scale: 2 # Fuel Consumption (Litres)
      t.decimal :fuel_bnd, precision: 10, scale: 2 # Fuel Consumption (BND$)
      t.decimal :ice_litres, precision: 10, scale: 2 # Ice Supply (Litres)
      t.decimal :ice_bnd, precision: 10, scale: 2 # Ice Supply (BND$)
      t.decimal :ration_bnd, precision: 10, scale: 2 # Ration (BND$)

      t.timestamps
    end

    add_index :capture_report_expenses, :capture_report_id, unique: true
  end
end
