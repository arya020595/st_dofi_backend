module Notifications
  class ProfilingPublisher
    EVENTS = {
      vessel_amendment_required: ["Vessel / Boat Amendment Required", "Vessel / Boat",
                                  "%<resource>s requires an amendment."],
      vessel_approved: ["Vessel / Boat Approved", "Vessel / Boat", "%<resource>s has been approved."],
      fishing_gear_amendment_required: ["Fishing Gear Amendment Required", "Fishing Gear",
                                        "%<resource>s requires an amendment."],
      crew_amendment_required: ["Crew Amendment Required", "Crew", "%<resource>s requires an amendment."],
      crew_approved: ["Crew Approved", "Crew", "%<resource>s has been approved."],
      document_amendment_required: ["Document Amendment Required", "Document",
                                    "%<resource>s requires an amendment."],
      document_approved: ["Document Approved", "Document", "%<resource>s has been approved."]
    }.freeze

    def self.call(...) = new.call(...)

    def call(event:, resource:)
      title, resource_label, message_template = EVENTS.fetch(event.to_sym)
      PublishToUsers.call(
        users: recipients_for(resource.company_profile_id),
        attributes: notification_attributes(event, resource, title, resource_label, message_template),
        resource:
      )
    end

    private

    def recipients_for(company_profile_id)
      User.kept
          .joins(:role)
          .where(status: "active", fisherman_status: "active", company_profile_id:)
          .where(roles: { platform_scope: Role::FISHERMAN_PLATFORM })
          .where("roles.is_default = ? OR roles.is_default_admin = ?", true, true)
          .distinct
    end

    def notification_attributes(event, resource, title, resource_label, message_template)
      {
        notification_type: "profiling.#{event}",
        title:,
        message: "#{resource_label} #{format(message_template, resource: resource_name(resource))}",
        metadata: resource_metadata(resource)
      }
    end

    def resource_metadata(resource)
      {
        company_profile_id: resource.company_profile_id,
        resource_id: resource.id,
        resource_type: resource.class.base_class.name,
        amendment_remarks: resource.amendment_remarks
      }
    end

    def resource_name(resource)
      case resource
      when CompaniesVessel then resource.vessel_name
      when CompaniesFishingGear then fishing_gear_name(resource)
      when CompaniesCrew then resource.crew_name
      when CompaniesDocument then resource.document_type.humanize
      end
    end

    def fishing_gear_name(resource)
      resource.local_name.presence || resource.fishing_gear_name || resource.fishing_gear.name
    end
  end
end
