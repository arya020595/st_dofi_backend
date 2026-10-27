module Api
  module V1
    class AttachmentsController < ApplicationController
      DISPOSITIONS = %w[inline attachment].freeze

      # Company-owned files have no policy of their own: company_profiles.* is the single gate for a
      # company's whole profile (see CompanyProfilePolicy), dispatched here by the owning record's type.
      # Anything absent from this table (e.g. Dictionary) resolves its own policy the Pundit default way.
      POLICY_CLASS_BY_RECORD_TYPE = {
        "CompaniesDocument" => CompanyProfilePolicy,
        "CompaniesVessel" => CompanyProfilePolicy
      }.freeze

      # find_signed! raises this directly (rather than ActiveRecord::RecordNotFound, which
      # ApplicationController already rescues) for a tampered, malformed, or expired signed_id.
      rescue_from ActiveSupport::MessageVerifier::InvalidSignature, with: :render_not_found

      # The object is gone from storage although the blob row exists.
      rescue_from ActiveStorage::FileNotFoundError, with: :render_not_found

      # GET /api/v1/attachments/:signed_id
      #
      # Authorization is evaluated here, at the moment the file is actually requested, not when
      # the JSON payload referencing it was built (see docs/minio/MINIO.md §3-4 and the spec this
      # follows). A signed_id only proves Rails issued it — it is not itself proof of access.
      #
      # Rails relays the bytes (no redirect to storage): only the backend server may reach the file
      # storage server, so the browser must never be sent a storage URL. Files are small (<= 10 MB),
      # hence send_data; send_blob_stream's ActionController::Live clashes with Devise/Warden.
      def show
        blob = ActiveStorage::Blob.find_signed!(params.expect(:signed_id))
        attachment = attachment_for(blob)

        authorize attachment.record, :show?, policy_class: POLICY_CLASS_BY_RECORD_TYPE[attachment.record_type]

        # After authorize on purpose: a revisit gets a bodyless 304, but only if it is still allowed to see the file.
        return unless stale?(etag: blob.checksum)

        # The bytes now leave from the API's own origin, so risky types (HTML, SVG, XML, JS) are served as an
        # opaque download instead of being rendered.
        send_data blob.download, type: blob.content_type_for_serving, disposition: disposition_for(blob),
                                 filename: blob.filename.sanitized
      end

      private

      def attachment_for(blob)
        blob.attachments.first || raise(ActiveRecord::RecordNotFound)
      end

      def disposition_for(blob)
        requested = DISPOSITIONS.include?(params[:disposition]) ? params[:disposition] : "inline"
        blob.forced_disposition_for_serving || requested
      end
    end
  end
end
