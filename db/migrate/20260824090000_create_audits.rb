class CreateAudits < ActiveRecord::Migration[8.1]
  def change
    create_table :audits, id: :uuid do |t|
      t.uuid :auditable_id
      t.string :auditable_type
      t.uuid :associated_id
      t.string :associated_type
      t.uuid :user_id
      t.string :user_type
      t.string :username
      t.string :action
      t.jsonb :audited_changes
      t.integer :version, default: 0
      t.string :comment
      t.string :remote_address
      t.string :request_uuid
      t.datetime :created_at

      t.index %i[auditable_type auditable_id version], name: "auditable_index"
      t.index %i[associated_type associated_id], name: "associated_index"
      t.index %i[user_id user_type], name: "user_index"
      t.index :request_uuid
      t.index :created_at
    end
  end
end
