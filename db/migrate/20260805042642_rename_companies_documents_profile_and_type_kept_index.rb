class RenameCompaniesDocumentsProfileAndTypeKeptIndex < ActiveRecord::Migration[8.1]
  OLD_NAME = "idx_companies_documents_on_profile_and_type_kept".freeze
  NEW_NAME = "index_companies_documents_on_profile_and_type_kept".freeze

  # The original migration (20260729094354) named this index idx_..., but the schema.rb committed
  # in that same commit already had it as index_... (matching this codebase's convention for every
  # other index) — the two have been out of sync since day one. Conditional on both sides so this
  # is a safe no-op on whichever name a given environment actually has, converging everyone on the
  # index_... name without editing the original migration (already on origin/develop).
  def up
    return unless index_name_exists?(:companies_documents, OLD_NAME)

    rename_index :companies_documents, OLD_NAME, NEW_NAME
  end

  def down
    return unless index_name_exists?(:companies_documents, NEW_NAME)

    rename_index :companies_documents, NEW_NAME, OLD_NAME
  end
end
