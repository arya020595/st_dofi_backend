FactoryBot.define do
  factory :companies_document do
    company_profile
    document_type { CompaniesDocument::DOCUMENT_TYPES.first }

    after(:build) do |document|
      document.file.attach(
        io: Rails.root.join("test/fixtures/files/sample.pdf").open,
        filename: "sample.pdf",
        content_type: "application/pdf"
      )
    end

    trait :approved do
      approval_status { "approved" }
    end
  end
end

# == Schema Information
#
# Table name: companies_documents
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  amendment_remarks  :text
#  approval_status    :string           default("pending"), not null
#  approved_at        :datetime
#  discarded_at       :datetime
#  document_type      :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  approved_by_id     :uuid
#  company_profile_id :uuid             not null
#
# Indexes
#
#  index_companies_documents_on_approved_by_id         (approved_by_id)
#  index_companies_documents_on_company_profile_id     (company_profile_id)
#  index_companies_documents_on_discarded_at           (discarded_at)
#  index_companies_documents_on_profile_and_type_kept  (company_profile_id,document_type) UNIQUE WHERE (discarded_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (approved_by_id => users.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#
