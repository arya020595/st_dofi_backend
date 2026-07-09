class RemoveReferenceIdFromCaptureReports < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_index :capture_reports, :reference_id
      remove_column :capture_reports, :reference_id, :string, null: false
    end
  end
end
