class CreateCompaniesDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :companies_documents, id: :uuid do |t|
      t.references :company_profile, null: false, foreign_key: true, type: :uuid
      t.string :document_type, null: false
      t.string :approval_status, null: false, default: "pending"
      t.text :amendment_remarks
      t.references :approved_by, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :approved_at
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :companies_documents, :discarded_at

    kept_type_index_options = { unique: true, where: "discarded_at IS NULL",
                                name: "idx_companies_documents_on_profile_and_type_kept" }
    add_index :companies_documents, %i[company_profile_id document_type], **kept_type_index_options
  end
end
