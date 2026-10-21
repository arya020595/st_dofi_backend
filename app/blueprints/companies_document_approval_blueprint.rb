class CompaniesDocumentApprovalBlueprint < Blueprinter::Base
  identifier :id

  fields :document_type, :approval_status, :amendment_remarks, :company_profile_id, :created_at, :updated_at

  field :document_url do |record|
    next nil unless record.file.attached?

    Rails.application.routes.url_helpers.api_v1_attachment_path(record.file.blob.signed_id)
  end
end
