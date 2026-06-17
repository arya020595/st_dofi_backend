class CreateManifestHistories < ActiveRecord::Migration[8.1]
  def change
    create_table :manifest_histories, id: :uuid do |t|
      t.references :manifest, null: false, foreign_key: true, type: :uuid
      t.string :action, null: false # e.g. "approve_port_out"
      t.string :status_type # "port_out", "port_in", "catch"
      t.string :from_state
      t.string :to_state
      t.text :remarks
      t.references :changed_by, type: :uuid, foreign_key: { to_table: :users }
      t.jsonb :metadata, default: {}

      t.timestamps
    end
  end
end
