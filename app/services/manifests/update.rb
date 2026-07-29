module Manifests
  class Update
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, attributes, company_profile: nil)
      return Failure(manifest) unless manifest.editable?

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

    def attributes_for_update(manifest, attributes, company_profile)
      update_attributes = attributes.except(:crew_ids, :ad_hoc_crew)
      return update_attributes unless company_profile

      if update_attributes.key?(:companies_vessel_id)
        update_vessel_snapshot!(manifest, update_attributes, company_profile)
      end
      if update_attributes.key?(:companies_captain_id)
        update_captain_snapshot!(manifest, update_attributes, company_profile)
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
      if attributes[:companies_captain_id].blank?
        clear_captain_snapshot!(attributes)
        return
      end

      captain = approved_captain!(manifest, company_profile, attributes[:companies_captain_id])
      attributes.merge!(companies_captain: captain,
                        captain_name: captain.captain_name,
                        captain_ic_number: captain.ic_number)
    end

    def approved_captain!(manifest, company_profile, captain_id)
      company_profile.companies_captains.kept.approved.find(captain_id)
    rescue ActiveRecord::RecordNotFound
      manifest.errors.add(:companies_captain_id, "must reference an approved captain owned by this company")
      raise ActiveRecord::RecordInvalid, manifest
    end

    def clear_captain_snapshot!(attributes)
      attributes.merge!(companies_captain: nil, captain_name: nil, captain_ic_number: nil)
    end
  end
end
