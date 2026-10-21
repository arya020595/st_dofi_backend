class CreateNationalities < ActiveRecord::Migration[8.1]
  def change
    create_table :nationalities, id: :uuid do |t|
      t.string :name, null: false # "Bruneian", "Malaysian", etc.
      t.string :code # "BN", "MY"
      t.boolean :is_local_citizenship, null: false, default: false

      t.timestamps
    end

    add_index :nationalities, :name, unique: true
    add_index :nationalities, :code
  end
end
