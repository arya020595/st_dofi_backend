module CompanyProfiles
  class SyncApprovalStatus
    APPROVABLE_ASSOCIATIONS = %i[
      companies_vessels
      companies_fishing_gears
      companies_crews
      companies_documents
    ].freeze

    def self.mark_pending!(company_profile)
      new(company_profile).mark_pending!
    end

    def self.refresh_after_review!(company_profile, actor:)
      new(company_profile).refresh_after_review!(actor: actor)
    end

    def initialize(company_profile)
      @company_profile = company_profile
    end

    def mark_pending!
      company_profile.update!(
        approval_status: "pending",
        approved_at: nil,
        approved_by: nil,
        date_approval: nil
      )
    end

    def refresh_after_review!(actor:)
      return mark_pending! unless approvables.all?(&:approved?)

      company_profile.update!(
        approval_status: "approved",
        approved_at: Time.current,
        approved_by: actor.id,
        date_approval: Date.current
      )
    end

    private

    attr_reader :company_profile

    def approvables
      @approvables ||= APPROVABLE_ASSOCIATIONS.flat_map do |association_name|
        company_profile.public_send(association_name).kept.to_a
      end
    end
  end
end
