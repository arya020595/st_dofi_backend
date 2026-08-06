module Manifests
  class Create
    include Dry::Monads[:result]

    # Denormalized onto the manifest (drives the dual-path AASM guards) from the company_profile's
    # own registration_type — never client-submitted, same reasoning as company_profile itself
    # (see Users::RegisterFisherman). An unrecognized registration_type maps to nil, which
    # Manifest's own `validates :fisherman_category, presence: true` already catches cleanly.
    FISHERMAN_CATEGORY_BY_REGISTRATION_TYPE = {
      "Commercial" => "commercial",
      "Small-Scale (Company)" => "small_scale_company",
      "Small - Scale (Full-Time)" => "small_scale_full_time",
      "Small - Scale (Part-Time)" => "small_scale_part_time"
    }.freeze

    def self.call(...) = new.call(...)

    # company_profile is server-derived from the acting fisherman, never client-submitted — see
    # Users::RegisterFisherman for the precedent of not trusting client input for identity/ownership.
    def call(attributes, company_profile:, actor:)
      manifest = build_manifest(attributes, company_profile, actor)
      return Failure(manifest) unless vessel_valid?(manifest) && captain_valid?(manifest, attributes[:captain_crew_id])

      ActiveRecord::Base.transaction do
        manifest.save!
        SetCrew.call(manifest, crew_ids: attributes[:crew_ids], ad_hoc_crew: attributes[:ad_hoc_crew])
      end
      Success(manifest)
    rescue ActiveRecord::RecordInvalid
      Failure(manifest)
    end

    private

    def build_manifest(attributes, company_profile, actor)
      Manifest.new(sanitized_attributes(attributes).merge(
                     manifest_number: next_manifest_number, created_by: actor, company_profile: company_profile,
                     company_name: company_profile.company_name,
                     fisherman_category: FISHERMAN_CATEGORY_BY_REGISTRATION_TYPE[company_profile.registration_type],
                     **snapshots(attributes, company_profile)
                   ))
    end

    def snapshots(attributes, company_profile)
      vessel = company_profile.companies_vessels.kept.find_by(id: attributes[:companies_vessel_id])
      captain = find_captain(company_profile, attributes[:captain_crew_id])
      support_vessel = find_support_vessel(company_profile, attributes[:support_vessel_id])

      vessel_snapshot(vessel).merge(captain_snapshot(captain)).merge(support_vessel_snapshot(support_vessel))
    end

    def sanitized_attributes(attributes)
      attributes.except(:crew_ids, :ad_hoc_crew, :companies_vessel_id, :captain_crew_id, :support_vessel_id,
                        :fisherman_category)
    end

    def find_captain(company_profile, captain_crew_id)
      return nil if captain_crew_id.blank?

      company_profile.companies_crews.kept.find_by(id: captain_crew_id)
    end

    def find_support_vessel(company_profile, support_vessel_id)
      return nil if support_vessel_id.blank?

      company_profile.companies_vessels.kept.find_by(id: support_vessel_id)
    end

    def vessel_snapshot(vessel)
      { companies_vessel: vessel, vessel_boat_name: vessel&.vessel_name, vessel_boat_no: vessel&.boat_number }
    end

    def captain_snapshot(captain)
      { captain_crew: captain, captain_name: captain&.crew_name, captain_ic_number: captain&.ic_number }
    end

    def support_vessel_snapshot(vessel)
      { support_vessel: vessel, support_vessel_name: vessel&.vessel_name, support_vessel_no: vessel&.boat_number }
    end

    def vessel_valid?(manifest)
      return true if manifest.companies_vessel&.approved?

      manifest.errors.add(:companies_vessel_id, "must reference an approved vessel owned by this company")
      false
    end

    # Checked against the originally requested id, not manifest.captain_crew_id — find_captain scopes
    # the lookup to this company, so a captain_crew_id for someone else's crew resolves to a nil
    # association, which would otherwise be indistinguishable from "no captain requested at all".
    def captain_valid?(manifest, requested_captain_crew_id)
      return true if requested_captain_crew_id.blank? || boat_captain?(manifest.captain_crew)

      manifest.errors.add(:captain_crew_id, "must reference an approved Boat Captain owned by this company")
      false
    end

    def boat_captain?(crew)
      crew&.approved? && crew.position&.name == "Boat Captain"
    end

    def next_manifest_number
      SequenceGenerator.next_value(key: :manifest_number, prefix: "DOF-#{Date.current.strftime('%Y%m%d')}-")
    end
  end
end
