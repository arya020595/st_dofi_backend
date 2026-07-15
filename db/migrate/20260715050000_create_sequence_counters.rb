class CreateSequenceCounters < ActiveRecord::Migration[8.1]
  def change
    create_table :sequence_counters, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :key, null: false
      t.integer :value, null: false, default: 0

      t.timestamps
    end

    add_index :sequence_counters, :key, unique: true
  end
end
