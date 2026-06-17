class CreateManifestSkipReasons < ActiveRecord::Migration[8.1]
  def change
    create_table :manifest_skip_reasons, id: :uuid do |t|
      t.string :reference_id, null: false # SR-001 (human-readable code)
      t.string :name, null: false
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :manifest_skip_reasons, :reference_id, unique: true
    add_index :manifest_skip_reasons, :discarded_at
  end
end
