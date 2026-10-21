class CreateApprovalRemarks < ActiveRecord::Migration[8.1]
  def change
    create_table :approval_remarks, id: :uuid do |t|
      t.string :reference_id, null: false # AR_001 (human-readable code)
      t.string :name, null: false
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :approval_remarks, :reference_id, unique: true
    add_index :approval_remarks, :name, unique: true
    add_index :approval_remarks, :discarded_at
  end
end
