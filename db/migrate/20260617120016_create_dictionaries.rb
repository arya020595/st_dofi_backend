class CreateDictionaries < ActiveRecord::Migration[8.1]
  def change
    create_table :dictionary_groups, id: :uuid do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :dictionary_groups, :name, unique: true

    create_table :dictionary_families, id: :uuid do |t|
      t.references :dictionary_group, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false

      t.timestamps
    end
    add_index :dictionary_families, %i[dictionary_group_id name], unique: true

    create_table :dictionaries, id: :uuid do |t|
      t.string :reference_id, null: false # SP-0001 (auto-generated)
      t.string :local_name, null: false # "Ikan Tenggiri"
      t.string :scientific_name # "Scomberomorus commerson"
      t.references :dictionary_group, null: false, foreign_key: true, type: :uuid
      t.references :dictionary_family, null: false, foreign_key: true, type: :uuid

      t.timestamps
      # fish_picture: stored via ActiveStorage (has_one_attached), added when ActiveStorage is set up
    end

    add_index :dictionaries, :reference_id, unique: true
    add_index :dictionaries, :local_name

    # Full-text search index using pg_trgm
    add_index :dictionaries, :local_name, using: :gin,
                                          opclass: :gin_trgm_ops,
                                          name: "idx_dictionaries_local_name_trgm"
    add_index :dictionaries, :scientific_name, using: :gin,
                                               opclass: :gin_trgm_ops,
                                               name: "idx_dictionaries_scientific_name_trgm"
  end
end
