class CreateZones < ActiveRecord::Migration[8.1]
  def change
    create_table :zones, id: :uuid do |t|
      t.string :name, null: false # "Zone A"
      t.string :zone_type # "Inshore", "Offshore", "Deep Sea"
      t.string :start_range # "0 nm"
      t.string :end_range # "12 nm"

      t.timestamps
    end
  end
end
