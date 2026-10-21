class CreateFishingGearDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :fishing_gear_details, id: :uuid do |t|
      t.references :capture_report, null: false, foreign_key: true, type: :uuid
      t.references :companies_fishing_gear, foreign_key: true, type: :uuid
      t.string :name # Denormalized gear name snapshot ("Trawl Net")
      t.string :gear_type # "Trawl", "Net", "Line"
      t.string :specification # Gear specification/length
      t.integer :quantity # Number of gear units used during this capture

      t.timestamps
    end
  end
end
