# Drops the storage behind the removed FINS Approval module: the approval_remarks master data and the
# users columns that only the approve/reject/revoke actions ever wrote. The pre-launch DB is refreshed
# rather than migrated row by row, so no values are carried anywhere; the audits table keeps history.
class DropFinsApprovalFields < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      remove_foreign_key :users, column: :revocation_remark_id
      remove_foreign_key :users, column: :revoked_by_id
      remove_foreign_key :users, column: :approved_by_id
      remove_index :users, :revocation_remark_id
      remove_index :users, :revoked_by_id

      change_table :users, bulk: true do |t|
        t.remove :revocation_remark_id, :revoked_by_id, :approved_by_id, :revoked_at, :revocation_comment,
                 :rejection_reason, :approved_at
      end

      drop_table :approval_remarks
    end
  end

  def down
    create_table :approval_remarks, id: :uuid do |t|
      t.string :name, null: false
      t.string :usage_scope, null: false, default: "both"
      t.datetime :discarded_at

      t.timestamps
    end
    add_index :approval_remarks, :name, unique: true
    add_index :approval_remarks, :discarded_at

    change_table :users, bulk: true do |t|
      t.datetime :approved_at
      t.uuid :approved_by_id
      t.text :rejection_reason
      t.datetime :revoked_at
      t.uuid :revoked_by_id
      t.uuid :revocation_remark_id
      t.text :revocation_comment
    end
    add_index :users, :revoked_by_id
    add_index :users, :revocation_remark_id
    add_foreign_key :users, :users, column: :approved_by_id, validate: false
    add_foreign_key :users, :users, column: :revoked_by_id, validate: false
    add_foreign_key :users, :approval_remarks, column: :revocation_remark_id, validate: false
  end
end
