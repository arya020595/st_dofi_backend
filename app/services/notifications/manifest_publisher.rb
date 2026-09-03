module Notifications
  class ManifestPublisher
    EVENTS = {
      port_out_review_required: [
        :approvers, "Port-Out Approval Required", "Manifest %<number>s is waiting for Port-Out approval."
      ],
      port_out_approved: [
        :fishermen, "Port-Out Approved", "Manifest %<number>s has been approved for Port-Out."
      ],
      port_out_amendment_required: [
        :fishermen, "Port-Out Amendment Required", "Manifest %<number>s requires a Port-Out amendment."
      ],
      capture_report_review_required: [
        :capture_verifiers,
        "Capture Report Review Required",
        "Manifest %<number>s has Capture Reports awaiting verification."
      ],
      capture_report_verified: [
        :fishermen, "Capture Report Verified", "A Capture Report for manifest %<number>s has been verified."
      ],
      capture_report_amendment_required: [
        :fishermen,
        "Capture Report Amendment Required",
        "A Capture Report for manifest %<number>s requires amendment."
      ],
      port_in_review_required: [
        :approvers, "Port-In Approval Required", "Manifest %<number>s is ready for Port-In approval."
      ],
      port_in_approved: [
        :fishermen, "Port-In Approved", "Manifest %<number>s has been approved for Port-In."
      ],
      port_in_amendment_required: [
        :fishermen, "Port-In Amendment Required", "Manifest %<number>s requires a Port-In amendment."
      ]
    }.freeze

    def self.call(...) = new.call(...)

    def call(event:, manifest:, capture_report: nil)
      recipient_group, title, message_template = EVENTS.fetch(event.to_sym)
      PublishToUsers.call(
        users: recipients_for(recipient_group, manifest),
        attributes: notification_attributes(event, manifest, title, message_template, capture_report),
        resource: manifest
      )
    end

    private

    def recipients_for(recipient_group, manifest)
      case recipient_group
      when :approvers then ManifestRecipients.approvers_for(manifest)
      when :capture_verifiers then ManifestRecipients.capture_verifiers_for(manifest)
      when :fishermen then ManifestRecipients.fishermen_for(manifest)
      end
    end

    def notification_attributes(event, manifest, title, message_template, capture_report)
      {
        notification_type: "manifest.#{event}",
        title: title,
        message: format(message_template, number: manifest.manifest_number),
        metadata: notification_metadata(manifest, capture_report)
      }
    end

    def notification_metadata(manifest, capture_report)
      {
        manifest_id: manifest.id,
        capture_report_id: capture_report&.id,
        manifest_status: manifest.manifest_status,
        port_out_status: manifest.port_out_status,
        port_in_status: manifest.port_in_status
      }.compact
    end
  end
end
