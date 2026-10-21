class AddForeignKeyManifestToManifestExpenses < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :manifest_expenses, :manifests, validate: false
  end
end
