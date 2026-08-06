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
      return update_attributes unless company_profile

      if update_attributes.key?(:companies_vessel_id)
        update_vessel_snapshot!(manifest, update_attributes, company_profile)
      end
      update_captain_snapshot!(manifest, update_attributes, company_profile) if update_attributes.key?(:captain_crew_id)
      if update_attributes.key?(:support_vessel_id)
        update_support_vessel_snapshot!(manifest, update_attributes, company_profile)
      end
      update_attributes
    end

    def update_vessel_snapshot!(manifest, attributes, company_profile)
      vessel = company_profile.companies_vessels.kept.approved.find(attributes[:companies_vessel_id])
      attributes.merge!(companies_vessel: vessel,
                        vessel_boat_name: vessel.vessel_name,
                        vessel_boat_no: vessel.boat_number)
    rescue ActiveRecord::RecordNotFound
      manifest.errors.add(:companies_vessel_id, "must reference an approved vessel owned by this company")
      raise ActiveRecord::RecordInvalid, manifest
    end

    def update_captain_snapshot!(manifest, attributes, company_profile)
      if attributes[:captain_crew_id].blank?
        clear_captain_snapshot!(attributes)
        return
      end

      captain = approved_captain!(manifest, company_profile, attributes[:captain_crew_id])
      attributes.merge!(captain_crew: captain,
                        captain_name: captain.crew_name,
                        captain_ic_number: captain.ic_number)
    end

    def approved_captain!(manifest, company_profile, captain_crew_id)
      crew = company_profile.companies_crews.kept.approved.find(captain_crew_id)
      return crew if crew.position&.name == "Boat Captain"

      raise ActiveRecord::RecordNotFound
    rescue ActiveRecord::RecordNotFound
      manifest.errors.add(:captain_crew_id, "must reference an approved Boat Captain owned by this company")
      raise ActiveRecord::RecordInvalid, manifest
    end

    def clear_captain_snapshot!(attributes)
      attributes.merge!(captain_crew: nil, captain_name: nil, captain_ic_number: nil)
    end

    def update_support_vessel_snapshot!(manifest, attributes, company_profile)
      if attributes[:support_vessel_id].blank?
        clear_support_vessel_snapshot!(attributes)
        return
      end

      vessel = approved_support_vessel!(manifest, company_profile, attributes[:support_vessel_id])
      attributes.merge!(support_vessel: vessel,
                        support_vessel_name: vessel.vessel_name,
                        support_vessel_no: vessel.boat_number)
    end

    def approved_support_vessel!(manifest, company_profile, support_vessel_id)
      company_profile.companies_vessels.kept.approved.find(support_vessel_id)
    rescue ActiveRecord::RecordNotFound
      manifest.errors.add(:support_vessel_id, "must reference an approved vessel owned by this company")
      raise ActiveRecord::RecordInvalid, manifest
    end

    def clear_support_vessel_snapshot!(attributes)
      attributes.merge!(support_vessel: nil, support_vessel_name: nil, support_vessel_no: nil)
    end
  end
end
