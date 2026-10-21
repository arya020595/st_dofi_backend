module CompaniesDocuments
  class Create
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(company_profile, attributes)
      document = company_profile.companies_documents.new(document_type: attributes[:document_type])
      file = attributes[:file]

      return attach_and_save(document, file) if file.present?

      persist(document)
    rescue ActiveStorage::IntegrityError, Aws::Errors::ServiceError, Seahorse::Client::NetworkingError => e
      document.errors.add(:file, "could not be uploaded: #{e.message}")
      Failure(document)
    end

    private

    def attach_and_save(document, file)
      return reject(document, "must be smaller than 10 MB") if file.size > CompaniesDocument::MAX_FILE_SIZE

      blob = Attachments::UploadFromParam.call(file, service_name: nil)
      unless CompaniesDocument::ALLOWED_CONTENT_TYPES.include?(blob.content_type)
        blob.purge
        return reject(document, "must be a PDF")
      end

      document.file.attach(blob)
      persist(document)
    end

    def persist(document)
      ActiveRecord::Base.transaction do
        return Failure(document) unless document.save

        CompanyProfiles::SyncApprovalStatus.mark_pending!(document.company_profile)
      end

      Success(document)
    end

    def reject(document, message)
      document.errors.add(:file, message)
      Failure(document)
    end
  end
end
