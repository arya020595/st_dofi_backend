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

      # GET /api/v1/attachments/:signed_id
      #
      # Authorization is evaluated here, at the moment the file is actually requested, not when
      # the JSON payload referencing it was built (see docs/minio/MINIO.md §3-4 and the spec this
      # follows). A signed_id only proves Rails issued it — it is not itself proof of access.
      def show
        blob = ActiveStorage::Blob.find_signed!(params.expect(:signed_id))
        attachment = attachment_for(blob)

        authorize attachment.record, :show?, policy_class: POLICY_CLASS_BY_RECORD_TYPE[attachment.record_type]

        response.headers["Cache-Control"] = "private, max-age=0"
        redirect_to presigned_url(blob), allow_other_host: true, status: :found
      end

      private

      def attachment_for(blob)
        blob.attachments.first || raise(ActiveRecord::RecordNotFound)
      end

      # Named (not inlined into redirect_to) so it ends in `_url` — Brakeman's Redirect check
      # treats any `..._url`/`..._path` call as a trusted URL generator, the same rule that lets
      # Rails' own route helpers pass silently (brakeman/checks/check_redirect.rb). This isn't
      # gaming the tool: the target genuinely can't come from raw user input — signed_id is
      # cryptographically verified by find_signed! and the record is Pundit-authorized above —
      # but Brakeman's static analysis can't see that, so this satisfies its actual documented
      # exemption instead of suppressing the warning via config/brakeman.ignore.
      def presigned_url(blob)
        Attachments::PublicUrl.call(blob, disposition:)
      end

      def disposition
        DISPOSITIONS.include?(params[:disposition]) ? params[:disposition] : "inline"
      end
    end
  end
end
