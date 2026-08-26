class CreateZones < ActiveRecord::Migration[8.1]
  def change
    create_table :zones, id: :uuid do |t|
      t.string :name, null: false # "Zone A"
      t.string :zone_type # "Inshore", "Offshore", "Deep Sea"
      t.integer :start_range # 0
      t.integer :end_range # 12

      t.timestamps
    end
  end
end
