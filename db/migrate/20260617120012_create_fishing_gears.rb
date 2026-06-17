class CreateFishingGears < ActiveRecord::Migration[8.1]
  def change
    create_table :fishing_gears, id: :uuid do |t|
      t.string :reference_id, null: false # FG-001 (auto-generated)
      t.string :name, null: false # "Drift Gill Net"
      t.string :gear_type, null: false # "Net", "Line", "Trawl"
      t.string :gear_specification # "30m", "500m", spec/length

      t.timestamps
    end

    add_index :fishing_gears, :reference_id, unique: true
    add_index :fishing_gears, :name
    add_index :fishing_gears, :gear_type
  end
end
