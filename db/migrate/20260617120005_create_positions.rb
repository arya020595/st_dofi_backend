class CreatePositions < ActiveRecord::Migration[8.1]
  def change
    create_table :positions, id: :uuid do |t|
      t.string :name, null: false # "Officer", "Port Operator", etc.

      t.timestamps
    end

    add_index :positions, :name, unique: true
  end
end
