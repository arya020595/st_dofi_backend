module Manifests
  class SetSupportVessels
    include Dry::Monads[:result]

    MAXIMUM_SUPPORT_VESSELS = 3

    def self.call(...) = new.call(...)

    def call(manifest, support_vessel_ids:, has_support_vessel:, company_profile:)
      vessel_ids = normalize_ids(support_vessel_ids)
      validate_input!(manifest, vessel_ids, has_support_vessel)
      vessels = eligible_vessels!(manifest, vessel_ids, company_profile)

      replace_support_vessels!(manifest, vessels)
      Success(manifest)
    rescue ActiveRecord::RecordInvalid
      Failure(manifest)
    end

    private

    def normalize_ids(ids)
      Array(ids).compact_blank.map(&:to_s)
    end

    def validate_input!(manifest, vessel_ids, has_support_vessel)
      errors = input_errors(vessel_ids, has_support_vessel)
      return if errors.empty?

      errors.each { |message| manifest.errors.add(:support_vessel_ids, message) }
      raise ActiveRecord::RecordInvalid, manifest
    end

    def input_errors(vessel_ids, has_support_vessel)
      [maximum_vessel_error(vessel_ids), duplicate_vessel_error(vessel_ids),
       missing_vessel_error(vessel_ids, has_support_vessel),
       unexpected_vessel_error(vessel_ids, has_support_vessel)].compact
    end

    def maximum_vessel_error(vessel_ids)
      return unless vessel_ids.size > MAXIMUM_SUPPORT_VESSELS

      "support_vessel_ids must include at most #{MAXIMUM_SUPPORT_VESSELS} vessels"
    end

    def duplicate_vessel_error(vessel_ids)
      "support_vessel_ids must not contain duplicate vessel ids" if vessel_ids.uniq.size != vessel_ids.size
    end

    def missing_vessel_error(vessel_ids, has_support_vessel)
      "support_vessel_ids must be provided when a support vessel is used" if has_support_vessel && vessel_ids.empty?
    end

    def unexpected_vessel_error(vessel_ids, has_support_vessel)
      "support_vessel_ids must be blank when no support vessel is used" if !has_support_vessel && vessel_ids.any?
    end

    def eligible_vessels!(manifest, vessel_ids, company_profile)
      vessels = company_profile.companies_vessels.kept.where(id: vessel_ids).index_by { |vessel| vessel.id.to_s }
      vessel_ids.map do |vessel_id|
        vessel = vessels[vessel_id]
        validate_vessel!(manifest, vessel, vessel_id)
        vessel
      end
    end

    def validate_vessel!(manifest, vessel, vessel_id)
      error = vessel_error(manifest, vessel, vessel_id)
      manifest.errors.add(:support_vessel_ids, error) if error
      raise ActiveRecord::RecordInvalid, manifest if manifest.errors.any?
    end

    def vessel_error(manifest, vessel, vessel_id)
      return "#{vessel_id} must reference a vessel owned by this company" if vessel.nil?
      return "#{vessel_id} must be approved" unless vessel.approved?
      return "#{vessel_id} must be a support vessel" unless vessel.category == "support_vessel"

      "#{vessel_id} must differ from the primary vessel" if vessel.id == manifest.companies_vessel_id
    end

    def replace_support_vessels!(manifest, vessels)
      manifest.manifest_support_vessels.destroy_all
      vessels.each do |vessel|
        manifest.manifest_support_vessels.create!(companies_vessel: vessel,
                                                  vessel_name: vessel.vessel_name,
                                                  boat_number: vessel.boat_number,
                                                  registration_no: vessel.registration_no)
      end

      first_vessel = vessels.first
      manifest.update!(has_support_vessel: vessels.any?, support_vessel: first_vessel,
                       support_vessel_name: first_vessel&.vessel_name, support_vessel_no: first_vessel&.boat_number)
    end
  end
end
