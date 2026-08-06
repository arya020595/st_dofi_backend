module Manifests
  class Update
    PORT_IN_FIELDS = %w[port_in_id port_in_datetime port_in_area].freeze

    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, attributes, company_profile: nil)
      return Failure(not_editable(manifest)) unless editable_for_update?(manifest, attributes)

      ActiveRecord::Base.transaction do
        manifest.update!(attributes_for_update(manifest, attributes, company_profile))
        if attributes.key?(:crew_ids) || attributes.key?(:ad_hoc_crew)
          SetCrew.call(manifest, crew_ids: attributes[:crew_ids], ad_hoc_crew: attributes[:ad_hoc_crew])
        end
      end
      Success(manifest)
    rescue ActiveRecord::RecordInvalid
      Failure(manifest)
    end

    private

    def editable_for_update?(manifest, attributes)
      manifest.editable? ||
        port_in_draft_update?(manifest, attributes) ||
        capture_report_amendment_update?(manifest)
    end

    def port_in_draft_update?(manifest, attributes)
      attribute_keys = attributes.keys.map(&:to_s)

      manifest.at_sea? &&
        manifest.port_in_draft? &&
        attribute_keys.all? { |key| PORT_IN_FIELDS.include?(key) }
    end

    def capture_report_amendment_update?(manifest)
      manifest.capture_report_submitted? && manifest.capture_reports.any?(&:needs_amendment?)
    end

    def not_editable(manifest)
      manifest.errors.add(:base, "Manifest is not editable")
      manifest
    end

    def attributes_for_update(manifest, attributes, company_profile)
      update_attributes = attributes.except(:crew_ids, :ad_hoc_crew)
      update_port_snapshot!(update_attributes)
      update_company_scoped_snapshots!(manifest, update_attributes, company_profile) if company_profile
      update_attributes
    end

    def update_company_scoped_snapshots!(manifest, attributes, company_profile)
      update_vessel_snapshot!(manifest, attributes, company_profile) if attributes.key?(:companies_vessel_id)
      update_captain_snapshot!(manifest, attributes, company_profile) if attributes.key?(:captain_crew_id)
      update_support_vessel_snapshot!(manifest, attributes, company_profile) if attributes.key?(:support_vessel_id)
    end

    def update_port_snapshot!(attributes)
      attributes[:port_out_name] = Snapshots.port_name(attributes[:port_out_id]) if attributes.key?(:port_out_id)
      attributes[:port_in_name] = Snapshots.port_name(attributes[:port_in_id]) if attributes.key?(:port_in_id)
    end

    def update_vessel_snapshot!(manifest, attributes, company_profile)
      vessel = approved_vessel!(manifest, company_profile, attributes[:companies_vessel_id], :companies_vessel_id)
      attributes.merge!(Snapshots.vessel(vessel))
    end

    def update_captain_snapshot!(manifest, attributes, company_profile)
      if attributes[:captain_crew_id].blank?
        attributes.merge!(Snapshots.captain(nil))
        return
      end

      captain = approved_captain!(manifest, company_profile, attributes[:captain_crew_id])
      attributes.merge!(Snapshots.captain(captain))
    end

    def approved_captain!(manifest, company_profile, captain_crew_id)
      crew = company_profile.companies_crews.kept.approved.find(captain_crew_id)
      return crew if crew.position&.name == "Boat Captain"

      raise ActiveRecord::RecordNotFound
    rescue ActiveRecord::RecordNotFound
      manifest.errors.add(:captain_crew_id, "must reference an approved Boat Captain owned by this company")
      raise ActiveRecord::RecordInvalid, manifest
    end

    def update_support_vessel_snapshot!(manifest, attributes, company_profile)
      if attributes[:support_vessel_id].blank?
        attributes.merge!(Snapshots.support_vessel(nil))
        return
      end

      vessel = approved_vessel!(manifest, company_profile, attributes[:support_vessel_id], :support_vessel_id)
      attributes.merge!(Snapshots.support_vessel(vessel))
    end

    # Shared by both the primary and support vessel — same "approved, owned by this company" rule,
    # only the attribute an error gets attached to differs.
    def approved_vessel!(manifest, company_profile, vessel_id, attribute_name)
      company_profile.companies_vessels.kept.approved.find(vessel_id)
    rescue ActiveRecord::RecordNotFound
      manifest.errors.add(attribute_name, "must reference an approved vessel owned by this company")
      raise ActiveRecord::RecordInvalid, manifest
    end
  end
end
