module Attachments
  class UploadFromParam
    # Uploads eagerly (rather than relying on ActiveStorage's default after_commit upload) so a
    # storage failure surfaces before the caller's record ever touches the database — the caller
    # decides what "before" means (before create, before update) by calling this first.
    #
    # content_type is detected from the file's magic bytes, not trusted from the client-reported
    # header — a mislabeled upload (e.g. a script sent with a spoofed "image/png" header) must
    # fail the model's own content-type validation, not be stored under a false type.
    def self.call(file, service_name:)
      io = file.respond_to?(:open) ? file.open : file
      detected_content_type = Marcel::MimeType.for(io, name: file.original_filename)
      io.rewind
      ActiveStorage::Blob.create_and_upload!(io: io, filename: file.original_filename,
                                             content_type: detected_content_type, service_name:)
    end
  end
end
