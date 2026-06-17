class CreateDictionaries < ActiveRecord::Migration[8.1]
  def change
    create_table :dictionaries, id: :uuid do |t|
      t.string :reference_id, null: false # SP-0001 (auto-generated)
      t.string :local_name, null: false # "Ikan Tenggiri"
      t.string :scientific_name # "Scomberomorus commerson"
      t.string :group_name # "Pelagic Fish"
      t.string :family_name # "Scombridae"

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
