class RemoveReferenceIdFromApprovalRemarks < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_index :approval_remarks, :reference_id
      remove_column :approval_remarks, :reference_id, :string, null: false
    end
  end
end
