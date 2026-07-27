class RemoveCaptureReportIdFromManifestExpenses < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_index :manifest_expenses, :capture_report_id, unique: true
      remove_reference :manifest_expenses, :capture_report, foreign_key: true, type: :uuid

      change_column_null :manifest_expenses, :manifest_id, false
      remove_index :manifest_expenses, :manifest_id
      add_index :manifest_expenses, :manifest_id, unique: true
    end
  end
end
