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
