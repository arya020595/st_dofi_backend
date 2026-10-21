class CreatePorts < ActiveRecord::Migration[8.1]
  def change
    create_table :ports, id: :uuid do |t|
      t.string :reference_id, null: false # PT-001 (auto-generated)
      t.string :port_name, null: false # "Serasa Port"
      t.decimal :latitude, precision: 10, scale: 8
      t.decimal :longitude, precision: 11, scale: 8

      t.timestamps
    end

    add_index :ports, :reference_id, unique: true
    add_index :ports, :port_name
  end
end
