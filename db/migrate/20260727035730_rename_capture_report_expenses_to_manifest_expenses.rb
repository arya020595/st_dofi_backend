class RenameCaptureReportExpensesToManifestExpenses < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      rename_table :capture_report_expenses, :manifest_expenses
    end
  end
end
