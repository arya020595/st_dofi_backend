module CompaniesDocuments
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    # Validates size/content-type before attaching, not after: `file` is `has_one_attached` on an
    # already-persisted document, so `.attach` replaces the previous file immediately regardless of
    # what a subsequent validation says — an invalid re-upload must never destroy a document that
    # was already approved.
    def call(document, file)
      return reject(document, "must be smaller than 10 MB") if file.size > CompaniesDocument::MAX_FILE_SIZE

      attach_valid_pdf(document, file)
    rescue ActiveStorage::IntegrityError, Aws::Errors::ServiceError, Seahorse::Client::NetworkingError => e
      document.errors.add(:file, "could not be uploaded: #{e.message}")
      Failure(document)
    end

    private

    def attach_valid_pdf(document, file)
      blob = Attachments::UploadFromParam.call(file, service_name: nil)
      unless CompaniesDocument::ALLOWED_CONTENT_TYPES.include?(blob.content_type)
        blob.purge
        return reject(document, "must be a PDF")
      end

      document.file.attach(blob)
      persist(document)
    end

    def persist(document)
      return Failure(document) unless document.save

      document.revert_to_pending_for_edit!
      Success(document)
    end

    def reject(document, message)
      document.errors.add(:file, message)
      Failure(document)
    end
  end
end
