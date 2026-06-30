class AddColumnsToFishingGears < ActiveRecord::Migration[8.1]
  def change
    change_table :fishing_gears, bulk: true do |t|
      t.string :local_name
      t.string :unit
      t.decimal :fee, precision: 10, scale: 2
      t.decimal :size, precision: 10, scale: 2
    end
  end
end
