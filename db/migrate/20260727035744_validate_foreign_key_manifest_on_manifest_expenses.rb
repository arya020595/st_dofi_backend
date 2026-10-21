class ValidateForeignKeyManifestOnManifestExpenses < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :manifest_expenses, :manifests
  end
end
