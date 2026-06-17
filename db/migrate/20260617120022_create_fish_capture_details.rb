class CreateFishCaptureDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :fish_capture_details, id: :uuid do |t|
      t.references :capture_report, null: false, foreign_key: true, type: :uuid
      t.references :dictionary, null: false, foreign_key: true, type: :uuid
      t.string :local_name # Denormalized snapshot
      t.string :scientific_name # Denormalized snapshot
      t.string :fish_type # Fish category type (e.g. "Demersal", "Pelagic")
      t.decimal :price_per_kg, precision: 10, scale: 2 # Price Per KG (BND)
      t.decimal :amount_captured_kg, precision: 10, scale: 3 # Amount Captured (KG)
      t.decimal :overall_total, precision: 12, scale: 2 # Calculated
      t.datetime :synced_at # Null = from offline queue

      t.timestamps
    end
  end
end
