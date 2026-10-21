class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.string :notification_type, null: false
      t.string :title, null: false
      t.text :message, null: false
      t.string :resource_type
      t.uuid :resource_id
      t.jsonb :metadata, null: false, default: {}
      t.datetime :read_at
      t.timestamps
    end

    add_index :notifications, %i[user_id read_at created_at], name: "index_notifications_for_user_inbox"
    add_index :notifications, %i[resource_type resource_id]
  end
end
