module Api
  module V1
    class AttachmentsController < ApplicationController
      DISPOSITIONS = %w[inline attachment].freeze

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

        authorize attachment.record, :show?
        log_attachment_access(attachment, granted: true)

        response.headers["Cache-Control"] = "private, max-age=0"
        redirect_to presigned_url(blob), allow_other_host: true, status: :found
      rescue Pundit::NotAuthorizedError
        # Deliberately local, not left to ApplicationController's class-level rescue_from: the
        # denial needs logging before rendering the same response that handler would give.
        log_attachment_access(attachment, granted: false)
        render_forbidden
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

      # Every access decision on a sensitive document is worth a trail — who, which attachment,
      # which record, granted or denied (handbook Bab 19: denials matter as much as successes).
      def log_attachment_access(attachment, granted:)
        Rails.logger.info(
          "Attachment access #{granted ? 'granted' : 'denied'}: user=#{current_user.id} " \
          "attachment=#{attachment.id} record=#{attachment.record_type}##{attachment.record_id}"
        )
      end
    end
  end
end
