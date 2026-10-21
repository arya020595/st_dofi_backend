class AddManifestIdToManifestExpenses < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  class MigrationManifestExpense < ActiveRecord::Base
    self.table_name = "manifest_expenses"
  end

  class MigrationCaptureReport < ActiveRecord::Base
    self.table_name = "capture_reports"
  end

  def up
    add_column :manifest_expenses, :manifest_id, :uuid
    add_index :manifest_expenses, :manifest_id, algorithm: :concurrently

    MigrationManifestExpense.reset_column_information
    # rubocop:disable Rails/SkipsModelValidations -- pure FK backfill on already-valid, already-persisted rows
    MigrationManifestExpense.find_each do |expense|
      capture_report = MigrationCaptureReport.find(expense.capture_report_id)
      expense.update_column(:manifest_id, capture_report.manifest_id)
    end
    # rubocop:enable Rails/SkipsModelValidations
  end

  def down
    remove_column :manifest_expenses, :manifest_id
  end
end
